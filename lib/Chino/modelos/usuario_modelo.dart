import 'package:cloud_firestore/cloud_firestore.dart';

/// Colección de Firestore con el perfil de cada usuario del sistema. El id
/// del documento es el `uid` de la cuenta en Firebase Authentication, así el
/// login puede buscar el perfil (rol, estado) directamente con ese uid.
const String kColeccionUsuarios = 'usuarios';

/// Roles disponibles en el formulario.
const List<String> kRolesUsuario = ['Administrador', 'Vendedor'];

/// Estados visibles en la app. Además existe 'Eliminado' (borrado lógico):
/// esos usuarios no se muestran en la lista y no pueden iniciar sesión.
const List<String> kEstadosUsuario = ['Activo', 'Inactivo'];
const String kEstadoEliminado = 'Eliminado';

/// Modelo de un usuario (perfil en Firestore + cuenta en Authentication).
///
/// Documento en `usuarios/{uid}`:
/// ```
/// {
///   "codigo": "U001",
///   "nombre": "Jose David Perez Martines",
///   "correo": "jose@email.com",
///   "telefono": "87342971",
///   "rol": "Vendedor",
///   "sucursal": "Norte",
///   "estado": "Activo",
///   "actualizadoEn": <Timestamp>
/// }
/// ```
/// La contraseña NUNCA se guarda aquí: vive solo en Authentication.
class Usuario {
  final String id; // uid de Firebase Authentication
  final String codigo;
  final String nombre;
  final String correo;
  final String telefono;
  final String rol;
  final String sucursal;
  final String estado;

  const Usuario({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.correo,
    required this.telefono,
    required this.rol,
    required this.sucursal,
    this.estado = 'Activo',
  });

  bool get activo => estado == 'Activo';
  bool get esAdministrador => rol == 'Administrador';

  factory Usuario.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Usuario(
      id: doc.id,
      codigo: (data['codigo'] ?? doc.id) as String,
      nombre: (data['nombre'] ?? '') as String,
      correo: (data['correo'] ?? '') as String,
      telefono: (data['telefono'] ?? '') as String,
      rol: (data['rol'] ?? 'Vendedor') as String,
      sucursal: (data['sucursal'] ?? '') as String,
      estado: (data['estado'] ?? 'Activo') as String,
    );
  }

  Map<String, dynamic> toMap() => {
        'codigo': codigo,
        'nombre': nombre,
        'correo': correo,
        'telefono': telefono,
        'rol': rol,
        'sucursal': sucursal,
        'estado': estado,
        'actualizadoEn': FieldValue.serverTimestamp(),
      };
}