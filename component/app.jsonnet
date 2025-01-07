local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.cluster_backup;
local argocd = import 'lib/argocd.libjsonnet';

local app = argocd.App('cluster-backup', params.namespace);

local appPath =
  local project = std.get(std.get(app, 'spec', {}), 'project', 'syn');
  if project == 'syn' then 'apps' else 'apps-%s' % project;

if params.enabled then {
  ['%s/cluster-backup' % appPath]: app,
} else {}
