pipeline {
   agent any

   parameters {
       choice(name: 'ACTION', choices: ['deploy', 'cleanup'], description: 'Choose pipeline action')
   }

   environment {
       PYTHON_VERSION = '3.x'
       GCP_PROJECT_ID = 'solid-altar-444910-c9'
       GCP_REGION = 'us-central1-a'
       GKE_CLUSTER_NAME = 'gke-cluster-one'
       ARTIFACT_REGISTRY_LOCATION = 'us-central1'
       ARTIFACT_REGISTRY_REPO = 'gabapprepoone'
       ARTIFACT_REGISTRY_HOSTNAME = "${ARTIFACT_REGISTRY_LOCATION}-docker.pkg.dev"
       TERRAFORM_DIR = 'terraform'
       CREDENTIALS_ID = 'kubernetes'
   }

   stages {
       stage('Deploy Pipeline') {
           when {
               expression { params.ACTION == 'deploy' }
           }
           stages {
               stage('Checkout') {
                   steps {
                       checkout scm
                   }
               }

               stage('Setup Python Environment') {
                   steps {
                       sh '''
                           python3 -m venv venv
                           . venv/bin/activate
                           python3 -m pip install --upgrade pip
                           pip install -r requirements.txt
                           pip install pytest flake8 bandit "safety>=2.3.5"
                       '''
                   }
               }

               stage('Run Tests') {
                   steps {
                       sh '''
                           . venv/bin/activate
                           python3 -m pytest test_app.py
                           python3 -m flake8 . --exclude=venv
                           find . -name "app.py" | xargs bandit || true
                           safety check
                       '''
                   }
               }

               stage('Terraform Init') {
                   steps {
                       dir('terraform') {
                           sh 'terraform init'
                       }
                   }
               }

               stage('Terraform Plan') {
                   steps { 
                       withCredentials([file(credentialsId: 'gcp-credentials', variable: 'GOOGLE_APPLICATION_CREDENTIALS')]) {
                           dir('terraform') {
                               sh '''
                                   gcloud auth activate-service-account --key-file=$GOOGLE_APPLICATION_CREDENTIALS
                                   gcloud config set project ${GCP_PROJECT_ID}
                                   terraform init
                                   terraform plan -out=tfplan
                               '''
                               stash includes: 'tfplan', name: 'terraform-plan'
                           }
                       }
                   }
               }

               stage('Terraform Apply') {
                   steps {
                       withCredentials([file(credentialsId: 'gcp-credentials', variable: 'GOOGLE_APPLICATION_CREDENTIALS')]) {
                           dir('terraform') {
                               sh '''
                                   gcloud auth activate-service-account --key-file=$GOOGLE_APPLICATION_CREDENTIALS
                                   gcloud config set project ${GCP_PROJECT_ID}
                                   terraform apply -auto-approve tfplan
                               '''
                           }
                       }
                   }
               }

               stage('Build and Push Docker Image') {
                   steps {
                       withCredentials([file(credentialsId: 'gcp-credentials', variable: 'GOOGLE_APPLICATION_CREDENTIALS')]) {
                           sh '''
                               gcloud auth activate-service-account --key-file=$GOOGLE_APPLICATION_CREDENTIALS
                               gcloud auth configure-docker ${ARTIFACT_REGISTRY_LOCATION}-docker.pkg.dev --quiet
                               docker build -t ${ARTIFACT_REGISTRY_HOSTNAME}/${GCP_PROJECT_ID}/${ARTIFACT_REGISTRY_REPO}/flask-app:latest .
                               docker push ${ARTIFACT_REGISTRY_HOSTNAME}/${GCP_PROJECT_ID}/${ARTIFACT_REGISTRY_REPO}/flask-app:latest
                           '''
                       }
                   }
               }

               stage('Deploy to GKE') {
                   steps {
                       sh '''
                           gcloud container clusters get-credentials ${GKE_CLUSTER_NAME} --region ${GCP_REGION} --project ${GCP_PROJECT_ID}
                           kubectl apply -f kubernetes/deployment.yaml
                           kubectl apply -f kubernetes/service.yaml
                           kubectl apply -f deploymenttwo.yaml
                           kubectl get pods
                           kubectl get svc
                       '''
                   }
               }
           }
       }

       stage('Cleanup') {
           when {
               expression { params.ACTION == 'cleanup' }
           }
           steps {
               withCredentials([file(credentialsId: 'gcp-credentials', variable: 'GOOGLE_APPLICATION_CREDENTIALS')]) {
                   sh '''
                       gcloud auth activate-service-account --key-file=$GOOGLE_APPLICATION_CREDENTIALS
                       gcloud config set project ${GCP_PROJECT_ID}
                       
                       gcloud container clusters get-credentials ${GKE_CLUSTER_NAME} --region ${GCP_REGION}
                       kubectl delete -f kubernetes/deployment.yaml || true
                       kubectl delete -f kubernetes/service.yaml || true
                       kubectl delete -f deploymenttwo.yaml || true
                       
                       cd terraform
                       terraform init
                       terraform destroy -auto-approve
                   '''
               }
           }
       }
   }

   post {
       always {
           cleanWs()
       }
       success {
           echo 'Pipeline completed successfully!'
       }
       failure {
           echo 'Pipeline failed. Please check the logs for details.'
       }
   }
}
