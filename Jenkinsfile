pipeline {
    agent any

    environment {
        PYTHON_VERSION = '3.x'
        GCP_PROJECT_ID = credentials('GCP_PROJECT_ID')
        GCP_CREDENTIALS = credentials('GCP_SA_KEY')
        GCP_REGION = credentials('GCP_REGION')
        GKE_CLUSTER_NAME = credentials('GKE_CLUSTER_NAME')
        GCR_HOSTNAME = 'gcr.io'
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
                    python -m venv venv
                    . venv/bin/activate
                    pip install -r requirements.txt
                    pip install pytest flake8 bandit safety
                '''
            }
        }

        stage('Run Tests') {
            steps {
                sh '''
                    . venv/bin/activate
                    python -m pytest
                    python -m flake8 . --exclude=venv
                    bandit -r . --exclude venv || true
                    safety check
                '''
            }
        }

        stage('Build and Push Docker Image') {
            steps {
                script {
                    // Authenticate with GCP
                    sh '''
                        echo "${GCP_CREDENTIALS}" > ${WORKSPACE}/gcp-key.json
                        gcloud auth activate-service-account --key-file=${WORKSPACE}/gcp-key.json
                        gcloud config set project ${GCP_PROJECT_ID}
                        gcloud auth configure-docker ${GCR_HOSTNAME}
                    '''

                    // Build and push Docker image
                    sh """
                        docker build -t ${GCR_HOSTNAME}/${GCP_PROJECT_ID}/flask-app:latest .
                        docker push ${GCR_HOSTNAME}/${GCP_PROJECT_ID}/flask-app:latest
                    """
                }
            }
        }

        stage('Deploy to GKE') {
            steps {
                sh '''
                    # Configure kubectl
                    gcloud container clusters get-credentials ${GKE_CLUSTER_NAME} --region ${GCP_REGION} --project ${GCP_PROJECT_ID}
                    
                    # Apply Kubernetes configurations
                    kubectl apply -f ./kubernetes/deployment.yaml
                    kubectl apply -f ./kubernetes/service.yaml
                    
                    # Check deployment status
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
            sh 'rm -f ${WORKSPACE}/gcp-key.json'
        }
    }
}
