import 'package:flutter/material.dart';

import 'AppDrawer.dart';
import '../modelos/evento_auditoria_modelo.dart';
import '../controladores/auditoria_service.dart';
import '../controladores/permisos_service.dart';
import '../controladores/apariencia_service.dart';
import 'filtros_comunes.dart';

// Colores
Color get _textoOscuro => Apariencia.instance.textoOscuro;
Color get _textoClaro => Apariencia.instance.textoClaro;
Color get _colorAcento => Apariencia.instance.acento;
Color get _colorBorde => Apariencia.instance.borde;
Color get _fondoInput => Apariencia.instance.fondoInput;

// Pantalla de auditoría
class AuditoriaScreen extends StatefulWidget {
  const AuditoriaScreen({super.key});

  @override
  State<AuditoriaScreen> createState() => _AuditoriaScreenState();
}

class _AuditoriaScreenState extends State<AuditoriaScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _buscadorController = TextEditingController();
  final AuditoriaService _auditoriaService = AuditoriaService();

  // Módulos de la bitácora
  static const List<String> _modulos = [
    'Todos',
    'Ventas',
    'Productos',
    'Stock',
    'Ingredientes',
    'Usuarios',
    'Sucursales',
    'Accesos',
  ];

  // Misma conexión para la lista y para las opciones de los filtros
  late final Stream<List<EventoAuditoria>> _stream =
      _auditoriaService.streamEventos();

  // Acción (Todos, Crear, Editar...) y módulo
  String _filtroSeleccionado = 'Todos';
  String _moduloSeleccionado = 'Todos';
  String _textoBusqueda = '';

  // Filtros desplegables
  String _filtroSucursal = '';
  String _filtroUsuario = '';
  DateTime? _filtroDesde;
  DateTime? _filtroHasta;

  bool get _hayFiltros =>
      _filtroSeleccionado != 'Todos' ||
      _moduloSeleccionado != 'Todos' ||
      _filtroSucursal.isNotEmpty ||
      _filtroUsuario.isNotEmpty ||
      _filtroDesde != null ||
      _filtroHasta != null;

  // Quitar todos los filtros
  void _quitarFiltros() {
    setState(() {
      _filtroSeleccionado = 'Todos';
      _moduloSeleccionado = 'Todos';
      _filtroSucursal = '';
      _filtroUsuario = '';
      _filtroDesde = null;
      _filtroHasta = null;
    });
  }

  // Sucursal del evento: la del registro afectado; si no hay, la de quien lo hizo
  String _sucursalDe(EventoAuditoria e) {
    for (final c in e.datosAdicionales) {
      if (c.etiqueta.trim().toLowerCase() == 'sucursal' &&
          c.valor.trim().isNotEmpty) {
        return c.valor.trim();
      }
    }
    return e.autorSucursal.trim();
  }

  // Tipos que tienen sentido según el módulo elegido:
  // Accesos solo tiene inicios de sesión; los demás módulos no.
  List<String> get _tiposDisponibles {
    if (_moduloSeleccionado == 'Accesos') {
      return const ['Todos', 'Inicio de sesión'];
    }
    if (_moduloSeleccionado == 'Todos') {
      return const ['Todos', 'Crear', 'Editar', 'Eliminar', 'Inicio de sesión'];
    }
    return const ['Todos', 'Crear', 'Editar', 'Eliminar'];
  }

  List<EventoAuditoria> _filtrar(List<EventoAuditoria> eventos) {
    return eventos.where((e) {
      final textoBusqueda = _textoBusqueda.toLowerCase();
      final coincideTexto = e.titulo.toLowerCase().contains(textoBusqueda) ||
          e.descripcion.toLowerCase().contains(textoBusqueda) ||
          e.autor.toLowerCase().contains(textoBusqueda) ||
          e.modulo.toLowerCase().contains(textoBusqueda) ||
          e.idReferencia.toLowerCase().contains(textoBusqueda);
      final coincideModulo = _moduloSeleccionado == 'Todos' ||
          e.modulo.trim().toLowerCase() == _moduloSeleccionado.toLowerCase();
      final coincideSucursal = _filtroSucursal.isEmpty ||
          _sucursalDe(e).toLowerCase() == _filtroSucursal.toLowerCase();
      final coincideUsuario =
          _filtroUsuario.isEmpty || e.autor.trim() == _filtroUsuario;
      final coincideFecha = fechaEnRango(e.fecha, _filtroDesde, _filtroHasta);
      final coincideFiltro = _filtroSeleccionado == 'Todos' ||
          (_filtroSeleccionado == 'Crear' && e.tipo == TipoEvento.crear) ||
          (_filtroSeleccionado == 'Editar' && e.tipo == TipoEvento.editar) ||
          (_filtroSeleccionado == 'Eliminar' && e.tipo == TipoEvento.eliminar) ||
          (_filtroSeleccionado == 'Inicio de sesión' &&
              e.tipo == TipoEvento.ingresar);
      return coincideTexto &&
          coincideFiltro &&
          coincideModulo &&
          coincideSucursal &&
          coincideUsuario &&
          coincideFecha;
    }).toList();
  }

  void _abrirDetalle(EventoAuditoria evento) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetalleEventoScreen(evento: evento)),
    );
  }

  @override
  void dispose() {
    _buscadorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Solo admin
    if (!Permisos.instance.puedeVer(ModuloApp.auditoria)) {
      return const AccesoRestringido(modulo: 'Auditoría');
    }
    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(moduloActual: ModuloApp.auditoria),
      body: SafeArea(
        child: Column(
          children: [
            ChinoTopBar(
              scaffoldKey: _scaffoldKey,
              subtitulo: 'Auditoría',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              Text(
                'Registro de auditoría',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _textoOscuro),
              ),
              const SizedBox(height: 4),
              Text(
                'Historial de acciones realizadas en el sistema',
                style: TextStyle(fontSize: 13, color: _textoClaro),
              ),
              const SizedBox(height: 16),

              // Buscador
              TextField(
                controller: _buscadorController,
                onChanged: (valor) => setState(() => _textoBusqueda = valor),
                decoration: InputDecoration(
                  hintText: 'Buscar evento...',
                  hintStyle: TextStyle(color: Apariencia.instance.hint, fontSize: 13),
                  prefixIcon: Icon(Icons.search, color: _textoClaro),
                  filled: true,
                  fillColor: _fondoInput,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _colorBorde),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _colorAcento),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Filtros desplegables
              StreamBuilder<List<EventoAuditoria>>(
                stream: _stream,
                builder: (context, snapshot) {
                  final datos = snapshot.data ?? const <EventoAuditoria>[];
                  return BarraFiltros(
                    hayFiltros: _hayFiltros,
                    onLimpiar: _quitarFiltros,
                    filtros: [
                      FiltroDesplegable(
                        icono: Icons.apps_outlined,
                        titulo: 'Módulo',
                        valor: _moduloSeleccionado == 'Todos'
                            ? ''
                            : _moduloSeleccionado,
                        opciones: {
                          '': 'Todos los módulos',
                          for (final m in _modulos.skip(1)) m: m,
                        },
                        onChanged: (v) => setState(() {
                          _moduloSeleccionado = v.isEmpty ? 'Todos' : v;
                          // Si la acción elegida ya no aplica al módulo, vuelve a Todos
                          if (!_tiposDisponibles.contains(_filtroSeleccionado)) {
                            _filtroSeleccionado = 'Todos';
                          }
                        }),
                      ),
                      FiltroDesplegable(
                        icono: Icons.storefront_outlined,
                        titulo: 'Sucursal',
                        valor: _filtroSucursal,
                        opciones: {
                          '': 'Todas las sucursales',
                          for (final s in opcionesUnicas(datos.map(_sucursalDe)))
                            s: s,
                        },
                        onChanged: (v) => setState(() => _filtroSucursal = v),
                      ),
                      FiltroDesplegable(
                        icono: Icons.bolt_outlined,
                        titulo: 'Acción',
                        valor: _filtroSeleccionado == 'Todos'
                            ? ''
                            : _filtroSeleccionado,
                        opciones: {
                          '': 'Todas las acciones',
                          for (final t in _tiposDisponibles.skip(1)) t: t,
                        },
                        onChanged: (v) => setState(
                          () => _filtroSeleccionado = v.isEmpty ? 'Todos' : v,
                        ),
                      ),
                      FiltroDesplegable(
                        icono: Icons.person_outline,
                        titulo: 'Usuario',
                        valor: _filtroUsuario,
                        opciones: {
                          '': 'Todos los usuarios',
                          for (final u in opcionesUnicas(datos.map((e) => e.autor)))
                            u: u,
                        },
                        onChanged: (v) => setState(() => _filtroUsuario = v),
                      ),
                      FiltroFecha(
                        etiqueta: 'Desde',
                        fecha: _filtroDesde,
                        maximo: _filtroHasta,
                        onChanged: (f) => setState(() => _filtroDesde = f),
                      ),
                      FiltroFecha(
                        etiqueta: 'Hasta',
                        fecha: _filtroHasta,
                        minimo: _filtroDesde,
                        onChanged: (f) => setState(() => _filtroHasta = f),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),

              // Bitácora en vivo
              StreamBuilder<List<EventoAuditoria>>(
                stream: _stream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _MensajeEstado(
                      icono: Icons.error_outline,
                      texto: 'Error al leer la auditoría: ${snapshot.error}',
                    );
                  }
                  if (!snapshot.hasData) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator(color: _colorAcento)),
                    );
                  }

                  final eventos = _filtrar(snapshot.data!);
                  if (eventos.isEmpty) {
                    final hayFiltros = snapshot.data!.isNotEmpty;
                    return _MensajeEstado(
                      icono: Icons.fact_check_outlined,
                      texto: hayFiltros
                          ? 'No hay eventos con los filtros seleccionados.\n'
                              'Cambia los filtros o la búsqueda.'
                          : 'Todavía no hay eventos registrados.\n'
                              'Aparecerán cuando se cree, edite o elimine algo en Ventas, '
                              'Productos, Stock, Usuarios y demás módulos, o al iniciar sesión.',
                    );
                  }

                  return Column(
                    children: eventos
                        .map((evento) => _TarjetaEvento(evento: evento, onTap: () => _abrirDetalle(evento)))
                        .toList(),
                  );
                },
              ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MensajeEstado extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _MensajeEstado({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(icono, size: 32, color: _textoClaro),
            const SizedBox(height: 8),
            Text(texto, textAlign: TextAlign.center, style: TextStyle(color: _textoClaro)),
          ],
        ),
      ),
    );
  }
}

class _TarjetaEvento extends StatelessWidget {
  final EventoAuditoria evento;
  final VoidCallback onTap;

  const _TarjetaEvento({required this.evento, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Apariencia.instance.superficie,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _colorBorde),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      evento.titulo,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textoOscuro),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Etiqueta(texto: evento.etiqueta, color: evento.colorEtiqueta),
                ],
              ),
              const SizedBox(height: 4),
              Text(evento.descripcion, style: TextStyle(fontSize: 12.5, color: _textoOscuro)),
              const SizedBox(height: 6),
              Text(
                [
                  evento.autor,
                  if (evento.modulo.trim().isNotEmpty) evento.modulo.trim(),
                  evento.fechaFormateada,
                ].join(' · '),
                style: TextStyle(fontSize: 11, color: _textoClaro),
              ),
              if (evento.productos.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${evento.productos.length} producto(s) involucrado(s) · toca para ver el detalle',
                    style: TextStyle(fontSize: 10.5, color: _colorAcento, fontStyle: FontStyle.italic),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final String texto;
  final Color color;

  const _Etiqueta({required this.texto, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(texto, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

// Detalle del evento

class DetalleEventoScreen extends StatelessWidget {
  final EventoAuditoria evento;

  const DetalleEventoScreen({super.key, required this.evento});

  static IconData _icono(TipoEvento t) {
    switch (t) {
      case TipoEvento.crear:
        return Icons.add_circle_outline;
      case TipoEvento.editar:
        return Icons.edit_outlined;
      case TipoEvento.eliminar:
        return Icons.delete_outline;
      case TipoEvento.ingresar:
        return Icons.login;
    }
  }

  // Valor de un dato adicional por su etiqueta
  String _dato(String etiqueta) {
    for (final c in evento.datosAdicionales) {
      if (c.etiqueta.trim().toLowerCase() == etiqueta.toLowerCase()) {
        return c.valor.trim();
      }
    }
    return '';
  }

  // Cambios "Campo: antes → después" y notas sueltas
  List<_Cambio> _cambios() {
    final texto = _dato('Detalle');
    if (texto.isEmpty) return const [];
    final lista = <_Cambio>[];
    for (final parte in texto.split(' · ')) {
      final t = parte.trim();
      if (t.isEmpty) continue;
      final flecha = t.indexOf('→');
      if (flecha == -1) {
        lista.add(_Cambio.nota(t));
        continue;
      }
      var antes = t.substring(0, flecha).trim();
      final despues = t.substring(flecha + 1).trim();
      var campo = '';
      final dosPuntos = antes.indexOf(':');
      if (dosPuntos != -1) {
        campo = antes.substring(0, dosPuntos).trim();
        antes = antes.substring(dosPuntos + 1).trim();
      }
      lista.add(_Cambio(campo, antes, despues));
    }
    return lista;
  }

  @override
  Widget build(BuildContext context) {
    final esAcceso = evento.tipo == TipoEvento.ingresar;
    final color = evento.colorEtiqueta;

    // Quién lo hizo (con respaldo en los datos adicionales)
    final rol = evento.autorRol.isNotEmpty ? evento.autorRol : _dato('Rol');
    final sucursal = evento.autorSucursal.isNotEmpty
        ? evento.autorSucursal
        : _dato('Sucursal');
    final correo =
        evento.autorCorreo.isNotEmpty ? evento.autorCorreo : _dato('Correo');

    final cambios = _cambios();
    final mostrarDatos = evento.datosAdicionales.where((c) {
      final et = c.etiqueta.trim().toLowerCase();
      if (et == 'detalle' && cambios.isNotEmpty) return false;
      if (esAcceso && (et == 'correo' || et == 'rol' || et == 'sucursal')) {
        return false;
      }
      return c.valor.trim().isNotEmpty;
    }).toList();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back, size: 18, color: _textoOscuro),
                    label: Text('Auditoría', style: TextStyle(color: _textoOscuro)),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Encabezado
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: color.withValues(alpha: 0.15),
                        child: Icon(_icono(evento.tipo), color: color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              evento.titulo,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: _textoOscuro,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              evento.hace,
                              style: TextStyle(fontSize: 12, color: _textoClaro),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _Etiqueta(texto: evento.etiqueta, color: color),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Qué pasó
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      evento.descripcion.trim().isEmpty
                          ? evento.queSignifica
                          : evento.descripcion,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                        color: _textoOscuro,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _TarjetaInfo(
                    titulo: 'Cuándo',
                    icono: Icons.schedule,
                    filas: [
                      ('Fecha', evento.fechaLarga),
                      ('Hora', evento.horaCompleta),
                      ('Transcurrido', evento.hace),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _TarjetaInfo(
                    titulo: 'Qué se hizo',
                    icono: Icons.fact_check_outlined,
                    filas: [
                      ('Acción', '${evento.etiqueta} · ${evento.queSignifica}'),
                      ('Módulo', evento.modulo),
                      ('Referencia', evento.idReferencia),
                      ('ID del evento', evento.id),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _TarjetaInfo(
                    titulo: 'Quién lo hizo',
                    icono: Icons.person_outline,
                    filas: [
                      ('Usuario', evento.autor),
                      ('Rol', rol),
                      ('Sucursal', sucursal),
                      ('Correo', correo),
                      ('Dispositivo', evento.plataforma),
                    ],
                  ),

                  // Cambios (antes → después)
                  if (cambios.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    Text(
                      'Qué cambió',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textoOscuro),
                    ),
                    const SizedBox(height: 10),
                    ...cambios.map((c) => _FilaCambio(cambio: c)),
                  ],

                  // Productos involucrados
                  if (evento.productos.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    Text(
                      'Productos involucrados (${evento.productos.length})',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textoOscuro),
                    ),
                    const SizedBox(height: 10),
                    ...evento.productos.map((p) => _TarjetaProductoMovimiento(producto: p)),
                    _TotalUnidades(productos: evento.productos),
                  ],

                  // Datos adicionales
                  if (mostrarDatos.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    _TarjetaInfo(
                      titulo: 'Datos del registro',
                      icono: Icons.list_alt_outlined,
                      filas: [
                        for (final c in mostrarDatos) (c.etiqueta, c.valor),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Un cambio: campo, valor anterior y nuevo (o una nota)
class _Cambio {
  final String campo;
  final String antes;
  final String despues;
  final String nota;

  const _Cambio(this.campo, this.antes, this.despues) : nota = '';
  const _Cambio.nota(this.nota)
      : campo = '',
        antes = '',
        despues = '';

  bool get esNota => nota.isNotEmpty;
}

class _FilaCambio extends StatelessWidget {
  final _Cambio cambio;

  const _FilaCambio({required this.cambio});

  Widget _valor(String texto, Color fondo, Color letra, {bool tachado = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        texto.isEmpty ? '(vacío)' : texto,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: letra,
          decoration: tachado ? TextDecoration.lineThrough : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Apariencia.instance.superficie,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _colorBorde),
      ),
      child: cambio.esNota
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: _textoClaro),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cambio.nota,
                    style: TextStyle(fontSize: 12.5, color: _textoOscuro),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (cambio.campo.isNotEmpty) ...[
                  Text(
                    cambio.campo,
                    style: TextStyle(fontSize: 12, color: _textoClaro),
                  ),
                  const SizedBox(height: 6),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _valor(cambio.antes, const Color(0xFFFDECEA),
                        const Color(0xFF9B2C2C), tachado: true),
                    Icon(Icons.arrow_forward, size: 16, color: _textoClaro),
                    _valor(cambio.despues, const Color(0xFFE8F5E9),
                        const Color(0xFF2E7D32)),
                  ],
                ),
              ],
            ),
    );
  }
}

// Tarjeta con filas "etiqueta: valor" (omite las vacías)
class _TarjetaInfo extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final List<(String, String)> filas;

  const _TarjetaInfo({
    required this.titulo,
    required this.icono,
    required this.filas,
  });

  @override
  Widget build(BuildContext context) {
    final visibles = filas.where((f) => f.$2.trim().isNotEmpty).toList();
    if (visibles.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Apariencia.instance.superficie,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _colorBorde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 18, color: _colorAcento),
              const SizedBox(width: 8),
              Text(
                titulo,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _textoOscuro,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final f in visibles) ...[
            Divider(height: 18, color: _colorBorde),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 112,
                  child: Text(
                    f.$1,
                    style: TextStyle(fontSize: 12, color: _textoClaro),
                  ),
                ),
                Expanded(
                  child: SelectableText(
                    f.$2,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _textoOscuro,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// Tarjeta de producto
class _TarjetaProductoMovimiento extends StatelessWidget {
  final ProductoMovimiento producto;

  const _TarjetaProductoMovimiento({required this.producto});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _fondoInput,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _colorBorde),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  producto.nombre,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textoOscuro),
                ),
                if (producto.detalle != null) ...[
                  const SizedBox(height: 2),
                  Text(producto.detalle!, style: TextStyle(fontSize: 11, color: _textoClaro)),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _colorAcento.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${producto.cantidad} u.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _colorAcento),
            ),
          ),
        ],
      ),
    );
  }
}

// Total de unidades
class _TotalUnidades extends StatelessWidget {
  final List<ProductoMovimiento> productos;

  const _TotalUnidades({required this.productos});

  @override
  Widget build(BuildContext context) {
    final total = productos.fold<int>(0, (suma, p) => suma + p.cantidad);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          'Total: $total unidades',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textoOscuro),
        ),
      ),
    );
  }
}