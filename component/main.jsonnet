local backup = import 'lib/backup-k8up.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.cluster_backup;

local on_openshift = std.member([ 'openshift4', 'oke' ], inv.parameters.facts.distribution);

local defaultLabels(name) = {
  metadata+: {
    labels+: {
      'app.kubernetes.io/name': name,
      'app.kubernetes.io/component': 'cluster-backup',
      'app.kubernetes.io/managed-by': 'commodore',
    },
  },
};

local addDefaultLabels(objs) =
  std.map(function(obj) obj + defaultLabels(obj.metadata.name), objs);

// Define outputs below
{
  '10_object': addDefaultLabels(import 'object.jsonnet'),
  [if on_openshift then '20_ocp4_etcd']: addDefaultLabels(import 'ocp4-etcd.jsonnet'),
}
