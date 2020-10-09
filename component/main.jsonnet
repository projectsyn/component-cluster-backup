local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.cluster_backup;

// Define outputs below
{
  '01_namespace': kube.Namespace(params.namespace),
  '10_object': import 'object.jsonnet',
}
