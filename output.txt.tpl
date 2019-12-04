Password is:
{{ with secret "kv1/client1/dbsecrets" }}
{{ .Data.oraclePass }}
{{ end }}
