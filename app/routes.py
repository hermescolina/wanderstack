from flask import Blueprint, jsonify  # Import jsonify

main = Blueprint('main', __name__)

@main.route('/')
def home():
    return jsonify({"message": "Welcome to Wanderstack!"})

@main.route('/hello/<name>')
def hello(name):
    return jsonify({"message": f"Hello, {name}!"})
