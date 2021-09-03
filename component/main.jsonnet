local backup = import 'lib/backup-k8up.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.cluster_backup;

// Define outputs below
{
  '10_object': import 'object.jsonnet',
  '20_etcd': import 'etcd.jsonnet',
}
