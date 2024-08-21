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

  // from here: additional config and overrides that are necessary to backup
  // to SFTP instead of S3. These are only used if `params.backup_type=sftp`.
  local sftpRepository = kube.ConfigMap('%s-backup-repository' % name) {
    metadata+: {
      namespace: namespace,
    },
    data: {
      repository: 'sftp:%(host)s:%(path)s' % params.sftp,
    },
  };

  local sftpConfig = kube.Secret('%s-backup-sftp-config' % name) {
    metadata+: {
      namespace: namespace,
    },
    data:: {},
    stringData: {
      // ssh expects trailing newlines for private keys, for consistency we
      // add a trailing newline for the public key and known hosts as well.
      ssh_key: '%(ssh_private_key)s\n' % params.sftp,
      'ssh_key.pub': '%(ssh_public_key)s\n' % params.sftp,
      known_hosts: '%(ssh_known_hosts)s\n' % params.sftp,
      config: |||
        Host %(host)s
        User %(user)s
        Port %(port)s
        IdentityFile ~/.ssh/ssh_key
        %(extra_ssh_config)s
      ||| % params.sftp,
    },
  };

  local sftpPodConfig = kube._Object('k8up.io/v1', 'PodConfig', name) {
    metadata+: {
      namespace: namespace,
    },
    spec: {
      template: {
        spec: {
          containers: [
            {
              // name is mandatory
              name: 'backup',
              env: [
                {
                  name: 'HOME',
                  value: '/home/k8up',
                },
                {
                  name: 'RESTIC_REPOSITORY_FILE',
                  value: '/home/k8up/.job/repository',
                },
                {
                  name: 'RESTIC_PASSWORD_FILE',
                  value: '/home/k8up/.secret/password',
                },
              ],
            },
          ],
          volumes: [
            {
              name: 'ssh-config',
              secret: {
                defaultMode: 256,  // 0400
                secretName: sftpConfig.metadata.name,
              },
            },
            {
              name: 'restic-repository',
              configMap: {
                name: sftpRepository.metadata.name,
              },
            },
            {
              name: 'backup-secret',
              secret: {
                secretName: backupSecret.metadata.name,
              },
            },
          ],
        },
      },
    },
  };

  local sftpSchedule = schedule {
    spec+: {
      podConfigRef: {
        name: sftpPodConfig.metadata.name,
      },
      backend+: {
        // drop S3 config
        s3:: {},
        volumeMounts: [
          {
            name: 'ssh-config',
            mountPath: '/home/k8up/.ssh',
          },
          {
            name: 'restic-repository',
            mountPath: '/home/k8up/.job',
          },
          {
            name: 'backup-secret',
            mountPath: '/home/k8up/.secret',
          },
        ],
      },
    },
  };


  if params.backend_type == 's3' then
    [ backupSecret, bucketSecret, schedule ]
  else if params.backend_type == 'sftp' then
    [ backupSecret, sftpRepository, sftpConfig, sftpPodConfig, sftpSchedule ]
  else
    error "Backup backend type '%s' not supported by the component" % params.backend_type;

{
  Schedule: buildSchedule,
  RandomMinute: minute,
}
