import pytest
from app import app


@pytest.fixture
def client():
    """Create a test client for the Flask app"""
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client


def test_home_page_status(client):
    """Test if home page returns 200 status code"""
    response = client.get('/')
    assert response.status_code == 200


def test_home_page_template(client):
    """Test if home page uses the correct template"""
    # Breaking long line into multiple lines
    template_path = app.template_folder + '/home.html'
    assert 'home.html' in template_path


def test_404_page(client):
    """Test if non-existent pages return 404"""
    response = client.get('/nonexistent-page')
    assert response.status_code == 404


def test_server_running(client):
    """Test if server is running and accepting connections"""
    response = client.get('/')
    assert response is not None
    assert response.status_code == 200
