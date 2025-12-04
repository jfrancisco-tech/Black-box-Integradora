import UIKit

class HistorialCell: UITableViewCell {
    
    // Elementos de la UI
    let containerView = UIView()
    let iconImageView = UIImageView()
    let titleLabel = UILabel()
    let dateLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI() // También lo llamamos aquí por si se usa desde Storyboard
    }
    
    func setupUI() {
        self.backgroundColor = .clear
        self.selectionStyle = .none
        
        // 1. Contenedor (Tarjeta Gris)
        containerView.backgroundColor = UIColor(red: 0.16, green: 0.16, blue: 0.17, alpha: 1.0)
        containerView.layer.cornerRadius = 15
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)
        
        // 2. Icono
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.tintColor = .white
        containerView.addSubview(iconImageView)
        
        // 3. Título (Mensaje)
        titleLabel.font = UIFont.boldSystemFont(ofSize: 16)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2 // Permitir 2 líneas si es largo
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        // 4. Fecha
        dateLabel.font = UIFont.systemFont(ofSize: 12, weight: .light)
        dateLabel.textColor = .lightGray
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(dateLabel)
        
        // --- CONSTRAINTS (Responsivos) ---
        NSLayoutConstraint.activate([
            // Contenedor: Margen de 10px a los lados y 5px arriba/abajo
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5),
            
            // Icono: Izquierda, centrado verticalmente, tamaño fijo 30x30
            iconImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 15),
            iconImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 30),
            iconImageView.heightAnchor.constraint(equalToConstant: 30),
            
            // Título: A la derecha del icono, arriba
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 15),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -15),
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 15),
            
            // Fecha: Debajo del título
            dateLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            dateLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            dateLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            dateLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -15)
        ])
    }
    
    // Método para configurar datos fácilmente
    func configurar(con evento: EventoHistorial) {
        titleLabel.text = evento.mensaje
        dateLabel.text = "\(evento.fecha_bloque) • \(evento.hora)"
        
        // Colores e Iconos según tipo
        if evento.mensaje.contains("Alarma") || evento.mensaje.contains("Robo") || evento.mensaje.contains("Intento") {
            iconImageView.image = UIImage(systemName: "exclamationmark.triangle.fill")
            iconImageView.tintColor = .systemRed
        } else if evento.mensaje.contains("Abierta") {
            iconImageView.image = UIImage(systemName: "lock.open.fill")
            iconImageView.tintColor = .systemGreen
        } else {
            iconImageView.image = UIImage(systemName: "info.circle.fill")
            iconImageView.tintColor = .systemBlue
        }
    }
}
