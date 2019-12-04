# Vault PoV
Suggested steps for a Vault proof of value

Considerations:
- For this PoV, admin will use userpass auth, although in the real world any auth method will work.
- For Jenkins, we will use appRole for Jenkins auth, and appRole for client auth.
- If needed, we can create a userpass login for Jenkins in case the external service is not available, to simulate the workflow with the plugin
- The auth workflow on the Jenkins side (login to retrieve access token) will be managed by the [Jenkins Vault plugin](https://wiki.jenkins.io/display/JENKINS/HashiCorp+Vault+Plugin).
- The auth workflow and secret retrieval on the client side (login to retrieve access token) will be managed by Vault Agent.

## Start Vault 1
```
vault server -log-level=trace -dev -dev-root-token-id=root -dev-listen-address=127.0.0.1:8200 -dev-ha -dev-transactional
```
## Enter Enterprise License
```
export VAULT_ADDR=http://0.0.0.0:8200
export VAULT_TOKEN=root
vault write sys/license text="LICENSE GOES HERE"
```
-----

## Create Admin User
-	Start Vault
-	Open in Browser http://0.0.0.0:8200
-	Log in as root
-	Create admin policy "admin"
```
path "*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

```
-	Enable userpass auth method
-	Create admin user associated with policy 
```
vault write auth/userpass/users/admin password=gf6iQdeLW4WMZyno policies=admin
```
### Revoke root token
```
# Have to go to terminal
export VAULT_ADDR='http://0.0.0.0:8200'
export VAULT_TOKEN=
vault login -method=userpass username=admin password=gf6iQdeLW4WMZyno
vault token revoke root
```
### Recreate root token
```
# If need to recreate root token
vault operator generate-root -generate-otp
#one time password output
vault operator generate-root -init -otp=
#return nonce, which should be given to each key holder if shamir secret sharing
vault operator generate-root
# enter unseal key

# Now decode the token with the original otp
vault operator generate-root -decode=[ENCODED ROOT] -otp=[ONE TIME PASSWORD]
```
-----

## Create Client (machine) user and write secret
-	Enable approle auth method in UI
-	Create client policy "client1"
```
path "kv1/client1/*"
{
  capabilities = ["create", "read", "update", "delete", "list"]
}
```
-	Create approle
vault write auth/approle/role/client1 policies=client1 
-   Enable secret engine kv v1, named "kv1" in the UI
- Create secret for client in the UI
-	write kv1/client1/dbsecrets/oraclepass

## Create user for Jenkins
-	Create Jenkins policy "jenkins" to only allow retrieving secretIds and approleids
```
path "auth/approle/role/client1/secret-id"
{
  capabilities = ["create", "read", "update"]
}
path "/auth/approle/role/client1/role-id"
{
  capabilities = ["read"]
}
```
-	Create a Jenkins AppRole user
vault write auth/approle/role/jenkins policies=jenkins 

-	Get a Jenkins AppRole secret id
vault write auth/approle/role/jenkins/secret-id -force

-	Enter AppRole and SecretId on the Jenkins plugin

### (Optional) create Jenkins user for easy testing/debuging
```
vault write auth/userpass/users/jenkins password=myjenkins policies=jenkins
vault login -method=userpass username=jenkins password=myjenkins
```
-----

## Deploy client
-	Check if the following commands will work on the instance or if additional libraries need to be installed
```
# ssh to instance
## For authentication, we will use Vault Agent:
curl https://releases.hashicorp.com/vault/1.3.0/vault_1.3.0_linux_amd64.zip -o vault.zip
unzip vault.zip
# Create vault agent config

tee config.hcl <<EOF
pid_file = "./pidfile"

vault {
   address = "http://VAULT_ADDRESS_HERE:8200"
}

auto_auth {
   method {
      type = "approle" 
      config = {
       role_id_file_path = "role_id.txt"
       secret_id_file_path = "secret_id.txt"
       remove_secret_id_file_after_reading = "true"
      }
   }

   sink "file" {
       config = {
           path = "vault-token-via-agent"
       }
   }
}
template {
  source      = "output.txt.tpl"
  destination = "output.txt"
}

EOF

# Assume that Jenkins can login to Vault and has set VAULT_TOKEN, otherwise login manually in terminal to test
# export VAULT_ADDR=VAULTADDRESS_HERE
# vault login -method=userpass username=jenkins password=myjenkins

SECRET_ID=$(vault write -force -field=secret_id -f auth/approle/role/client1/secret-id)
ROLE_ID=$( vault read -field=role_id /auth/approle/role/client1/role-id)


# Now Jenkins writes the secret_id and the role:
tee role_id.txt <<EOF
$ROLE_ID
EOF

tee secret_id.txt <<EOF
$SECRET_ID
EOF

# Create template file (alternatively, can be regular file uploaded with scp or similar)
tee output.txt.tpl <<EOF
Password is:
{{ with secret "kv1/client1/dbsecrets" }}
{{ .Data.oraclePass }}
{{ end }}
EOF

# Run vault agent
vault agent -config=config.hcl
```
