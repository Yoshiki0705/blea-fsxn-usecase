import * as cdk from 'aws-cdk-lib';
import {
  aws_cloudwatch as cw,
  aws_cloudwatch_actions as cw_actions,
  aws_ec2 as ec2,
  aws_events as events,
  aws_events_targets as targets,
  aws_iam as iam,
  aws_lambda as lambda,
  aws_logs as logs,
  aws_sns as sns,
  aws_sqs as sqs,
} from 'aws-cdk-lib';
import { Construct } from 'constructs';

export interface MonitoringProps {
  monitoringNotifyEmail: string;
  monitoringSlackWorkspaceId: string;
  monitoringSlackChannelId: string;
  vpc: ec2.IVpc;
  lambdaSecurityGroup: ec2.ISecurityGroup;
  secretArn: string;
  cacheFileSystemId: string;
  cacheManagementEndpoint: string;
  originFileSystemId: string;
  cacheHitRatioAlarmThreshold: number;
  cacheCapacityAlarmThresholdPercent: number;
}

/**
 * FlexCache Monitoring: Custom metrics Lambda + CloudWatch Alarms.
 *
 * FlexCache metrics (cache hit ratio, miss count, latency) are NOT available
 * as native CloudWatch metrics. A dedicated Lambda polls ONTAP REST API
 * every 5 minutes and publishes custom CloudWatch metrics.
 */
export class Monitoring extends Construct {
  public readonly alarmTopic: sns.ITopic;

  constructor(scope: Construct, id: string, props: MonitoringProps) {
    super(scope, id);

    const region = cdk.Stack.of(this).region;

    // SNS Topic
    const topic = new sns.Topic(this, 'AlarmTopic');
    topic.addToResourcePolicy(
      new iam.PolicyStatement({
        effect: iam.Effect.ALLOW,
        principals: [new iam.ServicePrincipal('cloudwatch.amazonaws.com')],
        actions: ['sns:Publish'],
        resources: [topic.topicArn],
      }),
    );
    this.alarmTopic = topic;

    if (props.monitoringNotifyEmail) {
      new sns.Subscription(this, 'Email', {
        topic,
        protocol: sns.SubscriptionProtocol.EMAIL,
        endpoint: props.monitoringNotifyEmail,
      });
    }

    // ─── Custom Metrics Collection Lambda ───
    // Polls ONTAP REST API for FlexCache statistics every 5 min.
    // FSx for ONTAP does not expose FlexCache-specific metrics (hit ratio, miss count)
    // via native CloudWatch. This Lambda calls the ONTAP management endpoint
    // GET /api/storage/flexcache/flexcaches and GET /api/storage/volumes (for capacity)
    // to collect and publish these metrics.
    // TODO: For production use, consider extracting Lambda code to a separate file
    // under lib/lambda/ for easier unit testing and maintenance.
    const dlq = new sqs.Queue(this, 'MetricsDLQ', {
      retentionPeriod: cdk.Duration.days(7),
      encryption: sqs.QueueEncryption.SQS_MANAGED,
    });

    const metricsLambda = new lambda.Function(this, 'MetricsCollector', {
      runtime: lambda.Runtime.NODEJS_22_X,
      handler: 'index.handler',
      code: lambda.Code.fromInline(`
const https = require('node:https');
const { SecretsManagerClient, GetSecretValueCommand } = require('@aws-sdk/client-secrets-manager');
const { CloudWatchClient, PutMetricDataCommand, GetMetricDataCommand } = require('@aws-sdk/client-cloudwatch');

/**
 * Call ONTAP REST API via HTTPS.
 * FSx for ONTAP management endpoints use AWS-issued self-signed certificates
 * that are not in public CA chains. rejectUnauthorized:false is the documented
 * pattern for ONTAP REST API access from Lambda.
 */
function ontapRequest(host, path, username, password) {
  return new Promise((resolve, reject) => {
    const auth = Buffer.from(username + ':' + password).toString('base64');
    const options = {
      hostname: host,
      port: 443,
      path: path,
      method: 'GET',
      headers: { 'Authorization': 'Basic ' + auth, 'Accept': 'application/json' },
      rejectUnauthorized: false,
      timeout: 15000,
    };
    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => { body += chunk; });
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve(JSON.parse(body));
        } else {
          reject(new Error('ONTAP API ' + res.statusCode + ': ' + body.substring(0, 200)));
        }
      });
    });
    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error('ONTAP API timeout')); });
    req.end();
  });
}

/**
 * Retrieve the last published cumulative counter values from CloudWatch
 * to compute deltas (rate metrics) for the current interval.
 */
async function getPreviousCounters(cwClient, namespace, fsId) {
  const now = new Date();
  const fiveMinAgo = new Date(now.getTime() - 10 * 60 * 1000);
  try {
    const resp = await cwClient.send(new GetMetricDataCommand({
      StartTime: fiveMinAgo,
      EndTime: now,
      MetricDataQueries: [
        { Id: 'prevHits', MetricStat: { Metric: { Namespace: namespace, MetricName: 'CumulativeHitCount', Dimensions: [{ Name: 'FileSystemId', Value: fsId }] }, Period: 300, Stat: 'Maximum' } },
        { Id: 'prevMisses', MetricStat: { Metric: { Namespace: namespace, MetricName: 'CumulativeMissCount', Dimensions: [{ Name: 'FileSystemId', Value: fsId }] }, Period: 300, Stat: 'Maximum' } },
      ],
    }));
    const hits = resp.MetricDataResults?.find(r => r.Id === 'prevHits');
    const misses = resp.MetricDataResults?.find(r => r.Id === 'prevMisses');
    const prevHits = (hits?.Values?.length > 0) ? hits.Values[0] : null;
    const prevMisses = (misses?.Values?.length > 0) ? misses.Values[0] : null;
    return { prevHits, prevMisses };
  } catch (e) {
    console.warn('Could not retrieve previous counters:', e.message);
    return { prevHits: null, prevMisses: null };
  }
}

exports.handler = async () => {
  const region = process.env.REGION;
  const secretArn = process.env.SECRET_ARN;
  const cacheFileSystemId = process.env.CACHE_FS_ID;
  const managementEndpoint = process.env.MGMT_ENDPOINT;
  const NAMESPACE = 'FSxN/FlexCache';

  // 1. Get ONTAP credentials from Secrets Manager
  const smClient = new SecretsManagerClient({ region });
  const secretResp = await smClient.send(new GetSecretValueCommand({ SecretId: secretArn }));
  const secret = JSON.parse(secretResp.SecretString);
  const username = secret.username || 'fsxadmin';
  const password = secret.password;

  if (!password) {
    throw new Error('ONTAP password not found in secret');
  }

  const cwClient = new CloudWatchClient({ region });

  // 2. Query FlexCache volumes from ONTAP REST API
  let cacheHitRatio = 0;
  let cacheMissCount = 0;
  let originLatencyMs = 0;
  let capacityUsedPercent = 0;
  let currentHits = 0;
  let currentMisses = 0;
  let counterAvailable = false;

  try {
    const fcResp = await ontapRequest(
      managementEndpoint,
      '/api/storage/flexcache/flexcaches?fields=size,path,svm.name',
      username, password
    );

    if (fcResp.records && fcResp.records.length > 0) {
      const flexcache = fcResp.records[0];
      const fcUuid = flexcache.uuid;

      // Volume statistics (latency, capacity)
      const statsResp = await ontapRequest(
        managementEndpoint,
        '/api/storage/volumes/' + fcUuid + '?fields=statistics,space',
        username, password
      );

      if (statsResp.statistics) {
        const stats = statsResp.statistics;
        const latencyUs = (stats.latency_raw && stats.latency_raw.total) || 0;
        const opsCount = (stats.iops_raw && stats.iops_raw.total) || 1;
        // Average latency per operation (cumulative total / total ops)
        originLatencyMs = opsCount > 0 ? (latencyUs / opsCount) / 1000 : 0;
      }

      // Capacity
      if (statsResp.space) {
        const used = statsResp.space.used || 0;
        const size = statsResp.space.size || 1;
        capacityUsedPercent = (used / size) * 100;
      }

      // FlexCache hit/miss counters (cumulative)
      try {
        const counterResp = await ontapRequest(
          managementEndpoint,
          '/api/cluster/counter/tables/flexcache_per_volume/rows?id=' + fcUuid +
          '&counters=cache_miss_count,cache_hit_count',
          username, password
        );
        if (counterResp.records && counterResp.records.length > 0) {
          const counters = counterResp.records[0].counters || [];
          const hitCounter = counters.find(c => c.name === 'cache_hit_count');
          const missCounter = counters.find(c => c.name === 'cache_miss_count');
          currentHits = hitCounter ? parseInt(hitCounter.value, 10) : 0;
          currentMisses = missCounter ? parseInt(missCounter.value, 10) : 0;
          counterAvailable = true;
        }
      } catch (counterErr) {
        console.warn('FlexCache counter table unavailable:', counterErr.message);
      }
    }
  } catch (apiErr) {
    console.error('ONTAP API error:', apiErr.message);
    await cwClient.send(new PutMetricDataCommand({
      Namespace: NAMESPACE,
      MetricData: [{
        MetricName: 'CollectionErrors',
        Value: 1,
        Unit: 'Count',
        Dimensions: [{ Name: 'FileSystemId', Value: cacheFileSystemId }],
        Timestamp: new Date(),
      }],
    }));
    throw apiErr;
  }

  // 3. Compute delta-based hit ratio from cumulative counters
  if (counterAvailable) {
    const prev = await getPreviousCounters(cwClient, NAMESPACE, cacheFileSystemId);

    if (prev.prevHits !== null && prev.prevMisses !== null) {
      const deltaHits = Math.max(0, currentHits - prev.prevHits);
      const deltaMisses = Math.max(0, currentMisses - prev.prevMisses);
      const deltaTotal = deltaHits + deltaMisses;
      cacheHitRatio = deltaTotal > 0 ? (deltaHits / deltaTotal) * 100 : 0;
      cacheMissCount = deltaMisses;
    } else {
      // First invocation: no previous data, report 0 (no estimation)
      cacheHitRatio = 0;
      cacheMissCount = 0;
    }
  }
  // If counter not available: cacheHitRatio stays 0, no misleading estimation

  // 4. Publish metrics to CloudWatch
  const timestamp = new Date();
  const dims = [{ Name: 'FileSystemId', Value: cacheFileSystemId }];

  const metricsData = [
    { MetricName: 'CacheHitRatio', Value: cacheHitRatio, Unit: 'Percent' },
    { MetricName: 'CacheMissCount', Value: cacheMissCount, Unit: 'Count' },
    { MetricName: 'OriginLatencyMs', Value: originLatencyMs, Unit: 'Milliseconds' },
    { MetricName: 'CapacityUsedPercent', Value: capacityUsedPercent, Unit: 'Percent' },
    // Store cumulative counters for next invocation's delta calculation
    { MetricName: 'CumulativeHitCount', Value: currentHits, Unit: 'Count' },
    { MetricName: 'CumulativeMissCount', Value: currentMisses, Unit: 'Count' },
  ];

  if (!counterAvailable) {
    metricsData.push({ MetricName: 'CounterUnavailable', Value: 1, Unit: 'Count' });
  }

  await cwClient.send(new PutMetricDataCommand({
    Namespace: NAMESPACE,
    MetricData: metricsData.map(m => ({ ...m, Dimensions: dims, Timestamp: timestamp })),
  }));

  console.log(JSON.stringify({
    event: 'metrics_published',
    cacheHitRatio: cacheHitRatio.toFixed(1),
    cacheMissCount,
    originLatencyMs: originLatencyMs.toFixed(1),
    capacityUsedPercent: capacityUsedPercent.toFixed(1),
    counterAvailable,
    fsId: cacheFileSystemId,
  }));
  return { statusCode: 200, metricsCount: metricsData.length };
};
`),
      vpc: props.vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      securityGroups: [props.lambdaSecurityGroup],
      timeout: cdk.Duration.seconds(60),
      reservedConcurrentExecutions: 1,
      deadLetterQueue: dlq,
      logGroup: new logs.LogGroup(this, 'MetricsLogGroup', { retention: logs.RetentionDays.ONE_MONTH }),
      environment: {
        REGION: region,
        SECRET_ARN: props.secretArn,
        CACHE_FS_ID: props.cacheFileSystemId,
        MGMT_ENDPOINT: props.cacheManagementEndpoint,
      },
    });

    metricsLambda.addToRolePolicy(
      new iam.PolicyStatement({
        actions: ['secretsmanager:GetSecretValue'],
        resources: [props.secretArn],
      }),
    );
    metricsLambda.addToRolePolicy(
      new iam.PolicyStatement({
        actions: ['cloudwatch:PutMetricData'],
        resources: ['*'],
        conditions: { StringEquals: { 'cloudwatch:namespace': 'FSxN/FlexCache' } },
      }),
    );
    metricsLambda.addToRolePolicy(
      new iam.PolicyStatement({
        actions: ['cloudwatch:GetMetricData'],
        resources: ['*'],
      }),
    );

    // Schedule: every 5 minutes
    new events.Rule(this, 'MetricsSchedule', {
      schedule: events.Schedule.rate(cdk.Duration.minutes(5)),
      targets: [new targets.LambdaFunction(metricsLambda)],
    });

    // ─── Alarms (using custom metrics) ───

    const cacheHitAlarm = new cw.Alarm(this, 'CacheHitRatioAlarm', {
      metric: new cw.Metric({
        namespace: 'FSxN/FlexCache',
        metricName: 'CacheHitRatio',
        dimensionsMap: { FileSystemId: props.cacheFileSystemId },
        statistic: 'Average',
        period: cdk.Duration.minutes(10),
      }),
      threshold: props.cacheHitRatioAlarmThreshold,
      evaluationPeriods: 3,
      comparisonOperator: cw.ComparisonOperator.LESS_THAN_THRESHOLD,
      alarmDescription: `FlexCache hit ratio < ${props.cacheHitRatioAlarmThreshold}%. Remote users experiencing cache misses. Runbook: verify origin connectivity, check working set size vs cache size.`,
    });
    cacheHitAlarm.addAlarmAction(new cw_actions.SnsAction(topic));

    const capacityAlarm = new cw.Alarm(this, 'CacheCapacityAlarm', {
      metric: new cw.Metric({
        namespace: 'FSxN/FlexCache',
        metricName: 'CapacityUsedPercent',
        dimensionsMap: { FileSystemId: props.cacheFileSystemId },
        statistic: 'Average',
        period: cdk.Duration.minutes(10),
      }),
      threshold: props.cacheCapacityAlarmThresholdPercent,
      evaluationPeriods: 3,
      comparisonOperator: cw.ComparisonOperator.GREATER_THAN_THRESHOLD,
      alarmDescription: `FlexCache capacity > ${props.cacheCapacityAlarmThresholdPercent}%. Consider increasing cache FSxN storage. Runbook: expand cache or review LRU eviction.`,
    });
    capacityAlarm.addAlarmAction(new cw_actions.SnsAction(topic));

    // Origin FSxN throughput alarm (native metric)
    const originThroughputAlarm = new cw.Alarm(this, 'OriginThroughputAlarm', {
      metric: new cw.Metric({
        namespace: 'AWS/FSx',
        metricName: 'FileServerDiskThroughputUtilization',
        dimensionsMap: { FileSystemId: props.originFileSystemId },
        statistic: 'Average',
        period: cdk.Duration.minutes(5),
      }),
      threshold: 80,
      evaluationPeriods: 3,
      alarmDescription:
        'Origin FSxN throughput > 80%. FlexCache misses may increase. Runbook: scale origin throughput.',
    });
    originThroughputAlarm.addAlarmAction(new cw_actions.SnsAction(topic));

    // Metrics collection error alarm
    const collectionErrorAlarm = new cw.Alarm(this, 'CollectionErrorAlarm', {
      metric: new cw.Metric({
        namespace: 'FSxN/FlexCache',
        metricName: 'CollectionErrors',
        dimensionsMap: { FileSystemId: props.cacheFileSystemId },
        statistic: 'Sum',
        period: cdk.Duration.minutes(15),
      }),
      threshold: 2,
      evaluationPeriods: 1,
      comparisonOperator: cw.ComparisonOperator.GREATER_THAN_OR_EQUAL_TO_THRESHOLD,
      alarmDescription:
        'FlexCache metrics collection failing. Check Lambda logs and ONTAP management endpoint connectivity.',
    });
    collectionErrorAlarm.addAlarmAction(new cw_actions.SnsAction(topic));
  }
}
