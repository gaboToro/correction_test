variable "region" {
  description = "Región de AWS a usar"
  default     = "us-east-1"
}

variable "ami_id" {
  description = "ID de la AMI (Amazon Linux 2 es común para Docker)"
  # Busca una AMI de Amazon Linux 2 o similar para tu región.
  # Por ejemplo, una AMI que tenga Docker instalado o donde puedas instalarlo.
  # El ID de la AMI a continuación es solo un EJEMPLO para us-east-1. ¡Debes buscar el ID correcto y actual!
  default     = "ami-068c0051b15cdb816" 
}

variable "instance_type" {
  description = "Tipo de instancia EC2"
  default     = "t2.micro" # Apto para cuentas académicas/gratuitas
}

variable "docker_image_tag" {
  description = "Etiqueta de la imagen de Docker a desplegar"
  type = string

  validation {
    condition = length(var.docker_image_tag) > 0
    error_message = "docker_image_tag no puede estar vacio"
  }
}