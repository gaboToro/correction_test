# Usa la imagen base de Python más ligera
FROM python:3.9-slim

# Establece el directorio de trabajo dentro del contenedor
WORKDIR /app

# Copia los archivos de dependencia e instala Flask
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copia el código de la aplicación y la carpeta de templates
COPY backend/app.py .
COPY backend/templates/ templates/ 

# Expone el puerto que usa Flask
EXPOSE 80

# Comando para ejecutar la aplicación
CMD ["python", "app.py"]