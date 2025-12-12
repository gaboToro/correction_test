from flask import Flask, render_template

app = Flask(__name__, template_folder='templates') # Indicamos a Flask dónde buscar templates

@app.route('/')
def home():
    # Renderiza el archivo index.html.
    # Puedes pasar variables aquí si quieres, por ejemplo:
    # return render_template('index.html', version='1.0')
    return render_template('index.html')

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=80)