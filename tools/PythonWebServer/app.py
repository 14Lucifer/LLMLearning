from flask import Flask, send_from_directory, request
import logging

app = Flask(__name__)

# Configure logging
logging.basicConfig(
    filename='access_log.log',
    level=logging.INFO,
    format='%(asctime)s - %(message)s'
)

@app.before_request
def log_request_info():
    """ Log each incoming request """
    request_info = f"{request.remote_addr} - {request.method} {request.path}"
    logging.info(request_info)

# Define route for the home page
@app.route('/')
def index():
    return send_from_directory('.', 'index.html')

# Define route for one-time-payment with subpath handling
@app.route('/one-time-payment.html', defaults={'subpath': ''})
@app.route('/one-time-payment.html/<path:subpath>')
def one_time_payment(subpath):
    return send_from_directory('.', 'one-time-payment.html')

# Define route for split-payment with subpath handling
@app.route('/split-payment.html', defaults={'subpath': ''})
@app.route('/split-payment.html/<path:subpath>')
def split_payment(subpath):
    return send_from_directory('.', 'split-payment.html')

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=80)

