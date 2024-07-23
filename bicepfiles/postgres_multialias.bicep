import radius as radius


@description('Username for Postgres1 db.')
param userName1 string = 'postgres'

@description('Password for Postgres1 db.')
@secure()
param pgs_pwd1 string 

@description('Host for Postgres1 db.')
param host1 string = 'postgres1.corerp-resources-terraform-pg-app.svc.cluster.local'

@description('Username for Postgres2 db.')
param userName2 string = 'postgres'

@description('Password for Postgres2 db.')
@secure()
param pgs_pwd2 string

@description('Host for Postgres2 db.')
param host2 string = 'postgres2.corerp-resources-terraform-pg-app.svc.cluster.local'

resource env 'Applications.Core/environments@2023-10-01-preview' = {
  name: 'corerp-resources-terraform-pg-env'
  location: 'global'
  properties: {
    compute: {
      kind: 'kubernetes'
      resourceId: 'self'
      namespace: 'corerp-resources-terraform-pg-env'
    }
    recipeConfig: {
      terraform:{
        providers:{
          postgresql:[{
            alias: 'pgdb-test1'
            username: userName1
            password: pgs_pwd1
            sslmode: 'disable'
            host: host1
          }
          { alias: 'pgdb-test2'
            username: userName2
            password: pgs_pwd2
            sslmode: 'disable'
            host: host2
          }]
        }
      }
      env: {
          PGPORT: '5432'
      }
    }
    recipes: {
      'Applications.Core/extenders': {
        defaultpostgres: {
          templateKind: 'terraform'
          templatePath: 'git::https://github.com/lakshmimsft/lak-temp-public//postgres-multialias'
        }
      }
    }
  }
}

resource app 'Applications.Core/applications@2023-10-01-preview' = {
  name: 'corerp-resources-terraform-pg-app'
  location: 'global'
  properties: {
    environment: env.id
    extensions: [
      {
        kind: 'kubernetesNamespace'
        namespace: 'corerp-resources-terraform-pg-app'
      }
    ]
  }
}

resource pgsapp 'Applications.Core/extenders@2023-10-01-preview' = {
  name: 'pgs-resources-terraform-pgsapp'
  properties: {
    application: app.id
    environment: env.id
    recipe: {
      name: 'defaultpostgres'
      parameters: {
         password1: pgs_pwd1
         password2: pgs_pwd2
      }
    }
  }
}
	