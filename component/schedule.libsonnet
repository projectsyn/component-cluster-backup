local backup = import 'lib/backup-k8up.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.cluster_backup;


local minute(namespace) =
  std.foldl(function(x, y) x + y, std.encodeUTF8(std.md5(inv.parameters.cluster.name + namespace)), 0) % 60;

local buildSchedule(name, namespace, backupSchedule, pruneSchedule='10 */4 * * *') =
  local backupSecret = kube.Secret('%s-backup-password' % name) {
    metadata+: {
      namespace: namespace,
    },
    stringData: {
      password: params.password,
    },
  };

  local backupSecretRef = {
    key: 'password',
    name: backupSecret.metadata.name,
  };

  local bucketSecret = kube.Secret('%s-backup-s3-credentials' % name) {
    metadata+: {
      namespace: namespace,
    },

    stringData: {
      username: params.bucket.accesskey,
      password: params.bucket.secretkey,
    },
  };

  local bucketSecretRef = {
    name: bucketSecret.metadata.name,
    accesskeyname: 'username',
    secretkeyname: 'password',
  };

  local schedule = backup.Schedule(
    name,
    backupSchedule,
    keep_jobs=params.keepjobs,
    bucket=params.bucket.name,
    backupkey=backupSecretRef,
    s3secret=bucketSecretRef,
    create_bucket=false,
  ).schedule + backup.PruneSpec(pruneSchedule, 30, 20) {
    metadata+: {
      namespace: namespace,
    },
  };

  [ backupSecret, bucketSecret, schedule ];

{
  Schedule: buildSchedule,
  RandomMinute: minute,
}
