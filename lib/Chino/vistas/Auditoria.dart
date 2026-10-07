import 'package:flutter/material.dart';

import 'AppDrawer.dart';
import '../modelos/evento_auditoria_modelo.dart';
import '../controladores/auditoria_service.dart';

// Colores reutilizados del diseño de la app (mismos que en main.dart)
const Color _textoOscuro = Color(0xFF5A3E36);
const Color _textoClaro = Color(0xFF7A6B65);
const Color _colorAcento = Color(0xFFA65021);
const Color _colorBorde = Color(0xFFE8DFD8);
const Color _fondoInput = Color(0xFFFCFAF7);

/// Pantalla principal: "Auditoria".
///
/// Este módulo NO escribe nada: solo lee la colección `auditoria`, en la
/// que deberían escribir el resto de módulos (Ventas, Stock, Usuarios,
/// Accesos, Productos...) cada vez que crean/editan/eliminan/ingresan algo,
/// usando `AuditoriaService.registrarEvento(...)`. Por eso este módulo es
/// difícil de probar solo: la forma real de probarlo es generando eventos
/// desde los otros módulos, o cargando los datos de prueba de
/// `lib/Chino/controladores/seed_data.dart`.
class AuditoriaScreen extends StatefulWidget {
  const AuditoriaScreen({super.key});

  @override
  State<AuditoriaScreen> createState() => _AuditoriaScreenState();
}

class _AuditoriaScreenState extends State<AuditoriaScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _buscadorController = TextEditingController();
  final AuditoriaService _auditoriaService = AuditoriaService();

  String _filtroSeleccionado = 'Todos';
  String _textoBusqueda = '';

  List<EventoAuditoria> _filtrar(List<EventoAuditoria> eventos) {
    return eventos.where((e) {
      final textoBusqueda = _textoBusqueda.toLowerCase();
      final coincideTexto = e.titulo.toLowerCase().contains(textoBusqueda) ||
          e.descripcion.toLowerCase().contains(textoBusqueda);
      final coincideFiltro = _filtroSeleccionado == 'Todos' ||
          (_filtroSeleccionado == 'Crear' && e.tipo == TipoEvento.crear) ||
          (_filtroSeleccionado == 'Editar' && e.tipo == TipoEvento.editar) ||
          (_filtroSeleccionado == 'Eliminar' && e.tipo == TipoEvento.eliminar) ||
          (_filtroSeleccionado == 'Ingresar' && e.tipo == TipoEvento.ingresar);
      return coincideTexto && coincideFiltro;
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
              const Text(
                'Registro de auditoría',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _textoOscuro),
              ),
              const SizedBox(height: 4),
              const Text(
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
                  hintStyle: const TextStyle(color: Colors.black45, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: _textoClaro),
                  filled: true,
                  fillColor: _fondoInput,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _colorBorde),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _colorAcento),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Filtros tipo pill
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['Todos', 'Crear', 'Editar', 'Eliminar', 'Ingresar'].map((filtro) {
                  final seleccionado = _filtroSeleccionado == filtro;
                  return ChoiceChip(
                    label: Text(filtro),
                    selected: seleccionado,
                    onSelected: (_) => setState(() => _filtroSeleccionado = filtro),
                    labelStyle: TextStyle(
                      color: seleccionado ? Colors.white : _textoOscuro,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    selectedColor: _colorAcento,
                    backgroundColor: _fondoInput,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: seleccionado ? _colorAcento : _colorBorde),
                    ),
                    showCheckmark: false,
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              // Bitácora, en vivo desde Firestore.
              StreamBuilder<List<EventoAuditoria>>(
                stream: _auditoriaService.streamEventos(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _MensajeEstado(
                      icono: Icons.error_outline,
                      texto: 'Error al leer la auditoría: ${snapshot.error}',
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator(color: _colorAcento)),
                    );
                  }

                  final eventos = _filtrar(snapshot.data!);
                  if (eventos.isEmpty) {
                    return const _MensajeEstado(
                      icono: Icons.fact_check_outlined,
                      texto: 'Todavía no hay eventos registrados.\n'
                          'Se llenan cuando otros módulos (Ventas, Stock, Usuarios...) '
                          'llaman a AuditoriaService.registrarEvento(), o con los datos de prueba.',
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
            Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: _textoClaro)),
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
            color: Colors.white,
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
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textoOscuro),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Etiqueta(texto: evento.etiqueta, color: evento.colorEtiqueta),
                ],
              ),
              const SizedBox(height: 4),
              Text(evento.descripcion, style: const TextStyle(fontSize: 12.5, color: _textoOscuro)),
              const SizedBox(height: 6),
              Text(
                '${evento.autor} · ${evento.fechaFormateada}',
                style: const TextStyle(fontSize: 11, color: _textoClaro),
              ),
              if (evento.productos.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${evento.productos.length} producto(s) involucrado(s) · toca para ver el detalle',
                    style: const TextStyle(fontSize: 10.5, color: _colorAcento, fontStyle: FontStyle.italic),
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

// ---------------------------------------------------------------------------
// Pantalla de detalle: "Detalle del evento" (se abre al tocar un evento)
// ---------------------------------------------------------------------------

class DetalleEventoScreen extends StatelessWidget {
  final EventoAuditoria evento;

  const DetalleEventoScreen({super.key, required this.evento});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, size: 18, color: _textoOscuro),
                label: const Text('Auditoria', style: TextStyle(color: _textoOscuro)),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      evento.titulo,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _textoOscuro),
                    ),
                  ),
                  _Etiqueta(texto: evento.etiqueta, color: evento.colorEtiqueta),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'ID de referencia: ${evento.idReferencia}',
                style: const TextStyle(fontSize: 12, color: _textoClaro),
              ),
              const SizedBox(height: 22),

              // ----- Información general -----
              const Text(
                'Información general',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textoOscuro),
              ),
              const SizedBox(height: 14),
              _campoLectura('Descripción', evento.descripcion),
              const SizedBox(height: 14),
              _campoLectura('Módulo afectado', evento.modulo),
              const SizedBox(height: 14),
              _campoLectura('Realizado por', evento.autor),
              const SizedBox(height: 14),
              _campoLectura('Fecha y hora', evento.fechaFormateada),

              // ----- Productos involucrados (solo si aplica) -----
              if (evento.productos.isNotEmpty) ...[
                const SizedBox(height: 22),
                Text(
                  'Productos involucrados (${evento.productos.length})',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textoOscuro),
                ),
                const SizedBox(height: 10),
                ...evento.productos.map((p) => _TarjetaProductoMovimiento(producto: p)),
                _TotalUnidades(productos: evento.productos),
              ],

              // ----- Datos adicionales según el tipo de evento -----
              if (evento.datosAdicionales.isNotEmpty) ...[
                const SizedBox(height: 22),
                const Text(
                  'Datos adicionales',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textoOscuro),
                ),
                const SizedBox(height: 14),
                for (int i = 0; i < evento.datosAdicionales.length; i++) ...[
                  if (i > 0) const SizedBox(height: 14),
                  _campoLectura(evento.datosAdicionales[i].etiqueta, evento.datosAdicionales[i].valor),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Campo de solo lectura, con el mismo estilo visual que los inputs
  /// de Stock.dart pero sin permitir edición (la auditoría no se modifica).
  Widget _campoLectura(String etiqueta, String valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: const TextStyle(fontSize: 12, color: _textoClaro)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _fondoInput,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _colorBorde),
          ),
          child: Text(valor, style: const TextStyle(fontSize: 13, color: _textoOscuro)),
        ),
      ],
    );
  }
}

/// Tarjeta de un producto involucrado en el evento (nombre + cantidad).
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
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textoOscuro),
                ),
                if (producto.detalle != null) ...[
                  const SizedBox(height: 2),
                  Text(producto.detalle!, style: const TextStyle(fontSize: 11, color: _textoClaro)),
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
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _colorAcento),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pequeño resumen con el total de unidades sumando todos los productos.
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
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textoOscuro),
        ),
      ),
    );
  }
}
