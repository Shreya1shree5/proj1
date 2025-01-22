    pipeline {
    agent any

    environment {
        PYTHON_VERSION = '3.x'
        GCP_PROJECT_ID = 'solid-altar-444910-c9'
        GCP_REGION = 'us-central1-a'
        GKE_CLUSTER_NAME = 'gke-cluster-dev'
        ARTIFACT_REGISTRY_LOCATION = 'us-central1'
        ARTIFACT_REGISTRY_REPO = 'your-docker-repo'
        ARTIFACT_REGISTRY_HOSTNAME = "${ARTIFACT_REGISTRY_LOCATION}-docker.pkg.dev"
        TERRAFORM_DIR = 'terraform'  // Directory containing Terraform files
        CREDENTIALS_ID = 'kubernetes'
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
                dir('terraform') {
                    sh 'terraform plan -out=tfplan'
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                dir('terraform') {
                    sh 'terraform apply -auto-approve tfplan'
                }
            }
        }

        stage('Build and Push Docker Image') {
            steps {
                script {
                    sh """
                        # Configure Docker for Artifact Registry
                        gcloud auth configure-docker ${ARTIFACT_REGISTRY_LOCATION}-docker.pkg.dev --quiet
                        
                        # Build Docker image
                        docker build -t ${ARTIFACT_REGISTRY_HOSTNAME}/${GCP_PROJECT_ID}/${ARTIFACT_REGISTRY_REPO}/flask-app:latest .
                        
                        # Push to Artifact Registry
                        docker push ${ARTIFACT_REGISTRY_HOSTNAME}/${GCP_PROJECT_ID}/${ARTIFACT_REGISTRY_REPO}/flask-app:latest
                    """
                }
            }
        }

        stage('Deploy to GKE') {
            steps {
                sh '''
                    # Get GKE credentials
                    gcloud container clusters get-credentials ${GKE_CLUSTER_NAME} --region ${GCP_REGION} --project ${GCP_PROJECT_ID}
                    
                    # Apply Kubernetes manifests
                    kubectl apply -f kubernetes/deployment.yaml
                    kubectl apply -f kubernetes/service.yaml
                    
                    # Verify deployment
                    echo "Checking deployment status..."
                    kubectl get pods
                    kubectl get svc
                '''
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
