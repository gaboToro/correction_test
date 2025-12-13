import os
from flask import Flask, render_template

app = Flask(__name__, template_folder='templates') # Indicamos a Flask dónde buscar templates

@app.route('/')
def home():
    # Renderiza el archivo index.html.
    # Puedes pasar variables aquí si quieres, por ejemplo:
    # return render_template('index.html', version='1.0')
    return render_template('index.html', image_tag=os.getenv('IMAGE_TAG', 'dev'))

if __name__ == '__main__':
    debug_mode = os.getenv("FLASK_DEBUG", "false").lower() == "true"
    app.run(host='0.0.0.0', port=80)