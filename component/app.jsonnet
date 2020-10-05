local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.cluster_backup;
local argocd = import 'lib/argocd.libjsonnet';

local app = argocd.App('cluster-backup', params.namespace);

{
  'cluster-backup': app,
}
