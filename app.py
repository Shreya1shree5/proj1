from flask import Flask, render_template
import os

app = Flask(__name__)


@app.route('/')
def home():
    return render_template('home.html')


if __name__ == '__main__':
    # Use environment variables with secure defaults
    host = os.getenv('FLASK_HOST', '127.0.0.1')  # Default to localhost
    port = int(os.getenv('FLASK_PORT', 5000))
    app.run(host=host, port=port)
