from flask import Flask

app = Flask(__name__)


@app.get("/")
def greeting():
    return "Hello world from app! It is Pipeline testing."
