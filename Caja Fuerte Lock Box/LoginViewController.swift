//
//  LoginViewController.swift
//  LockBox
//
//  Created by Valeria Elizabeth Zapata Ibarra on 27/11/25.
//

import UIKit

class LoginViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Configuración inicial
    }
    
    // Función para el botón "INGRESAR"
    @IBAction func ingresoTocado(_ sender: Any) { // Nombre de la función en español
        print("Botón INGRESAR presionado")
    }
    
    // Función para cuando tocan el botón "Registrar Nuevo Usuario"
    // (Esta conexión se mantiene por si la usas con el botón)
    @IBAction func tocoRegistrar(_ sender: Any) {
        print("Yendo al registro de nuevo usuario")
    }
    
    // --- FUNCIÓN UNWIND SEGUE PARA EL BOTÓN CANCELAR ---
    // Esta función se llama cuando se toca "Cancelar" en la vista de Registro
    // y la cierra para regresar aquí.
    @IBAction func regresarAlLogin(_ segue: UIStoryboardSegue) {
        print("El usuario canceló y regresó a la pantalla de Login")
    }

}
