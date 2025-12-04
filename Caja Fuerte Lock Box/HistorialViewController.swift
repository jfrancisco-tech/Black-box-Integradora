import UIKit

class HistorialViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet weak var tabla: UITableView!
    
    var eventos: [EventoHistorial] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Estilo visual
        view.backgroundColor = UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)
        tabla.backgroundColor = .clear
        tabla.separatorStyle = .none // Quitamos líneas separadoras feas
        
        tabla.dataSource = self
        tabla.delegate = self
        
        // ⚠️ IMPORTANTE: Registrar la celda personalizada
        tabla.register(HistorialCell.self, forCellReuseIdentifier: "HistorialCell")
        
        cargarDatos()
    }
    
    func cargarDatos() {
        guard let url = URL(string: "https://api-sensores-348016469746.us-central1.run.app/api/historial") else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else { return }
            
            do {
                self.eventos = try JSONDecoder().decode([EventoHistorial].self, from: data)
                DispatchQueue.main.async { self.tabla.reloadData() }
            } catch {
                print("Error al cargar historial: \(error)")
            }
        }.resume()
    }
    
    // MARK: - Configuración de la Tabla
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return eventos.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        // 1. Obtenemos la celda y la convertimos a NUESTRA clase
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "HistorialCell", for: indexPath) as? HistorialCell else {
            return UITableViewCell()
        }
        
        // 2. Obtenemos el dato
        let evento = eventos[indexPath.row]
        
        // 3. Configuramos usando el método limpio que creaste
        cell.configurar(con: evento)
        
        return cell
    }
    
    // Opcional: Altura de celda un poco más grande para que se vea bien
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
}
