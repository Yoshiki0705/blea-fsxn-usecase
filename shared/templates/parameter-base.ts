/**
 * Shared base parameter interface for all FSxN BLEA use cases.
 * Each Spec extends this with use-case-specific parameters.
 */
import { Environment } from 'aws-cdk-lib';

/**
 * Common parameters across all FSxN BLEA use cases.
 */
export interface BaseParameter {
  env?: Environment;
  envName: string;

  // Monitoring (BLEA pattern)
  monitoringNotifyEmail: string;
  monitoringSlackWorkspaceId: string;
  monitoringSlackChannelId: string;

  // Networking
  vpcCidr: string;

  // FSx for ONTAP (common)
  fsxnStorageCapacityGiB: number; // Minimum: 1024
  fsxnThroughputCapacityMBps: number; // Allowed: 128, 256, 512, 1024, 2048, 4096
  fsxnDeploymentType: 'MULTI_AZ_1' | 'SINGLE_AZ_1';
}

/**
 * Valid FSxN throughput values.
 */
export const VALID_THROUGHPUTS = [128, 256, 512, 1024, 2048, 4096] as const;

/**
 * Minimum FSxN storage capacity in GiB.
 */
export const MIN_STORAGE_CAPACITY_GIB = 1024;

/**
 * Validate common FSxN parameters.
 * Call this in bin/ entry point before stack creation.
 */
export function validateBaseParameters(params: BaseParameter): void {
  if (!VALID_THROUGHPUTS.includes(params.fsxnThroughputCapacityMBps as any)) {
    throw new Error(
      `Invalid throughput capacity: ${params.fsxnThroughputCapacityMBps} MBps. ` +
        `Must be one of: ${VALID_THROUGHPUTS.join(', ')}`,
    );
  }
  if (params.fsxnStorageCapacityGiB < MIN_STORAGE_CAPACITY_GIB) {
    throw new Error(
      `Storage capacity must be >= ${MIN_STORAGE_CAPACITY_GIB} GiB. Got: ${params.fsxnStorageCapacityGiB}`,
    );
  }
}
