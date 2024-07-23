import radius as radius


@description('Username for Postgres db.')
param userName string = 'postgres'

@description('Password for Postgres db.')
@secure()
param password string = 'abc-123-hgd-@#$-1'


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
            username: userName
            password: password
            sslmode: 'disable'
            host: 'postgres.corerp-resources-terraform-pg-app.svc.cluster.local'
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
          templatePath: 'git::https://github.com/lakshmimsft/lak-temp-public//postgres-noalias'
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
         password: password
      }
    }
  }
}
	