local backup = import 'lib/backup-k8up.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.cluster_backup;

local onOpenshift = inv.parameters.facts.distribution == 'openshift4';

local nsLabels =
  if onOpenshift then
    {
      'network.openshift.io/policy-group': 'monitoring',
    }
  else
    {};

local backupSecret = kube.Secret('objects-backup-password') {
  stringData: {
    password: params.password,
  },
};

local backupSecretRef = {
  key: 'password',
  name: backupSecret.metadata.name,
};

local bucketSecret = kube.Secret('object-backup-s3-credentials') {
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

local schedule =
  local minute = std.foldl(function(x, y) x + y, std.encodeUTF8(std.md5(inv.parameters.cluster.name + params.namespace)), 0) % 60;
  backup.Schedule(
    'objects',
    '%d * * * *' % minute,
    keep_jobs=params.keepjobs,
    bucket=params.bucket.name,
    backupkey=backupSecretRef,
    s3secret=bucketSecretRef,
    create_bucket=false,
  ).schedule + backup.PruneSpec('10 */4 * * *', 30, 20) {
    metadata+: {
      namespace: params.namespace,
    },
  };

// Define outputs below
{
  '01_namespace': kube.Namespace(params.namespace) {
    metadata+: {
      labels+: nsLabels,
    },
  },
  '05_schedule': [ backupSecret, bucketSecret, schedule ],
  '10_object': import 'object.jsonnet',
}
