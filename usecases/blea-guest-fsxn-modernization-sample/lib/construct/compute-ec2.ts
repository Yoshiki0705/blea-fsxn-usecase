import { aws_autoscaling as asg, aws_ec2 as ec2, aws_iam as iam } from 'aws-cdk-lib';
import { Construct } from 'constructs';

export interface ComputeEc2Props {
  vpc: ec2.IVpc;
  ec2SecurityGroup: ec2.ISecurityGroup;
  nfsDnsName: string;
  junctionPath: string;
  instanceType: string;
  instanceArchitecture: 'ARM64' | 'X86_64';
  minCapacity: number;
  maxCapacity: number;
}

/**
 * EC2 Auto Scaling Group with NFS mount to FSx for ONTAP.
 * Pattern: Legacy application rehost (VMware → EC2).
 * Supports both x86_64 and ARM64 (Graviton) architectures for cost optimization.
 */
export class ComputeEc2 extends Construct {
  constructor(scope: Construct, id: string, props: ComputeEc2Props) {
    super(scope, id);

    const isArm64 = props.instanceArchitecture === 'ARM64';

    const role = new iam.Role(this, 'InstanceRole', {
      assumedBy: new iam.ServicePrincipal('ec2.amazonaws.com'),
      managedPolicies: [
        iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonSSMManagedInstanceCore'),
        iam.ManagedPolicy.fromAwsManagedPolicyName('CloudWatchAgentServerPolicy'),
      ],
    });

    // NFS mount options: Graviton benefits from nconnect=16 (multi-queue utilization)
    const nfsOpts = isArm64
      ? 'noresvport,hard,nfsvers=4.1,rsize=262144,wsize=262144,nconnect=16'
      : 'noresvport,hard,nfsvers=4.1,rsize=262144,wsize=262144';

    const userData = ec2.UserData.forLinux();
    userData.addCommands(
      'yum install -y nfs-utils',
      'mkdir -p /mnt/fsxn',
      `mount -t nfs -o ${nfsOpts} ${props.nfsDnsName}:${props.junctionPath} /mnt/fsxn`,
      `echo "${props.nfsDnsName}:${props.junctionPath} /mnt/fsxn nfs ${nfsOpts} 0 0" >> /etc/fstab`,
    );

    // Select AMI based on architecture
    const machineImage = ec2.MachineImage.latestAmazonLinux2023({
      cpuType: isArm64 ? ec2.AmazonLinuxCpuType.ARM_64 : ec2.AmazonLinuxCpuType.X86_64,
    });

    const launchTemplate = new ec2.LaunchTemplate(this, 'LaunchTemplate', {
      instanceType: new ec2.InstanceType(props.instanceType),
      machineImage,
      securityGroup: props.ec2SecurityGroup,
      role,
      userData,
    });

    new asg.AutoScalingGroup(this, 'ASG', {
      vpc: props.vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      launchTemplate,
      minCapacity: props.minCapacity,
      maxCapacity: props.maxCapacity,
    });
  }
}
