#!/bin/sh
# This script is supposed to run on the VM, NOT on the host!

salt_call()
{
  sudo salt-call "$1" "$2" | tail -1 | tr -d ' '
}

external_ip=$(salt_call network.interface_ip eth1)

concourse_username=$(salt_call pillar.get concourse:lookup:local_user)
concourse_password=$(salt_call pillar.get concourse:lookup:local_password)

s3_access_key=$(salt_call pillar.get minio:lookup:access_key)
s3_secret_key=$(salt_call pillar.get minio:lookup:secret_key)
s3_endpoint=$(salt_call pillar.get minio:lookup:endpoint)

vault_token=$(salt_call pillar.get vault:lookup:dev_root_token)

cat <<EOF

     Concourse web server:  http://${external_ip}:8080
                 Username:  ${concourse_username}
                 Password:  ${concourse_password}
                fly login:  fly -t vm login -c http://${external_ip}:8080 -u ${concourse_username} -p ${concourse_password}

      Minio S3 web server:  http://${external_ip}:9000
S3 endpoint for pipelines:  ${s3_endpoint}
            s3_access_key:  ${s3_access_key}
            s3_secret_key:  ${s3_secret_key}

             Vault status:  env VAULT_ADDR=http://${external_ip}:8200 vault status
           Login to Vault:  env VAULT_ADDR=http://${external_ip}:8200 vault login ${vault_token}

EOF

cat <<EOF > /vagrant/secrets.txt

# concourse-uri: http://${external_ip}:8080
# concourse-main-username: ${concourse_username}
# concourse-main-password: ${concourse_password}

export VAULT_ADDR="http://${external_ip}:8200"

# In case you shut down the VM after the first `vagrant up`, you need to issue
# this command, which sets the root path for the Concourse secrets:
#
# env VAULT_ADDR="http://${external_ip}:8200" vault secrets enable -path=/concourse kv

vault kv put /concourse/main/minio-endpoint       value=${s3_endpoint}
vault kv put /concourse/main/s3-access-key-id     value=${s3_access_key}
vault kv put /concourse/main/s3-secret-access-key value=${s3_secret_key}

EOF

echo "."
cat <<EOF
We just created file 'secrets.txt' in the current directory.
You can use that file to inject into Vault the parameters needed to use S3 storage.

1. Read the README on how to use Vault
2. Login to Vault
3. Read the secrets.txt file to understand what it does
4. Run it (sh secrets.txt)

You can now develop your pipelines securely, since the S3 credentials are stored in Vault.

See as an example tests/pipeline-s3.yml for how to refer to S3.
EOF
echo "."
