pid_file = "./pidfile"

vault {
   address = "http://0.0.0.0:8200"
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

