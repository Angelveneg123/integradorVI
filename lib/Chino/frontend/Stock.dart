import 'package:flutter/material.dart';

import 'AppDrawer.dart';
import '../backend/producto_modelo.dart';
import '../backend/productos_service.dart';
import '../backend/stock_service.dart';

// Colores reutilizados del diseño de la app (mismos que en main.dart)
const Color _textoOscuro = Color(0xFF5A3E36);
const Color _textoClaro = Color(0xFF7A6B65);
const Color _colorAcento = Color(0xFFA65021);
const Color _colorBorde = Color(0xFFE8DFD8);
const Color _fondoInput = Color(0xFFFCFAF7);

/// Pantalla principal: "Gestión de inventario".
///
/// Los productos vienen en tiempo real de Firestore (colección `productos`,
/// que llena el módulo de Productos). Este módulo solo lee esa colección y
/// escribe cambios de `stock` a través de [StockService].
class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _buscadorController = TextEditingController();
  final ProductosService _productosService = ProductosService();
  final StockService _stockService = StockService();

  String _filtroSeleccionado = 'Todos';
  String _textoBusqueda = '';

  List<Producto> _filtrar(List<Producto> productos) {
    return productos.where((p) {
      final coincideTexto = p.nombre.toLowerCase().contains(_textoBusqueda.toLowerCase());
      final coincideFiltro = _filtroSeleccionado == 'Todos' ||
          (_filtroSeleccionado == 'Activos' && p.activo) ||
          (_filtroSeleccionado == 'Inactivos' && !p.activo);
      return coincideTexto && coincideFiltro;
    }).toList();
  }

  Future<void> _abrirDetalle(Producto producto) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AjustarInventarioScreen(
          producto: producto,
          stockService: _stockService,
        ),
      ),
    );
    // No hace falta setState: el StreamBuilder de abajo se refresca solo
    // en cuanto Firestore confirma el cambio de stock.
  }

  Future<void> _cambioRapido(Producto producto, int delta) async {
    if (producto.stock + delta < 0) return;
    try {
      await _stockService.ajustarInventario(
        producto: producto,
        tipoAjuste: delta > 0 ? 'Entrada' : 'Salida',
        cantidad: delta.abs(),
        motivo: 'Ajuste rápido desde el listado',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar el stock: $e')),
      );
    }
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
      drawer: const AppDrawer(moduloActual: ModuloApp.stock),
      body: SafeArea(
        child: Column(
          children: [
            ChinoTopBar(
              scaffoldKey: _scaffoldKey,
              subtitulo: 'Inventario',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              const Text(
                'Gestión de inventario',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _textoOscuro),
              ),
              const SizedBox(height: 4),
              const Text(
                'Ajusta el stock y revisa el estado de cada producto',
                style: TextStyle(fontSize: 13, color: _textoClaro),
              ),
              const SizedBox(height: 16),

              // Buscador
              TextField(
                controller: _buscadorController,
                onChanged: (valor) => setState(() => _textoBusqueda = valor),
                decoration: InputDecoration(
                  hintText: 'Buscar producto...',
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

              // Filtros tipo pill: Todos / Activos / Inactivos
              Row(
                children: ['Todos', 'Activos', 'Inactivos'].map((filtro) {
                  final seleccionado = _filtroSeleccionado == filtro;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
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
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              // Lista de productos, en vivo desde Firestore.
              StreamBuilder<List<Producto>>(
                stream: _productosService.streamProductos(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _MensajeEstado(
                      icono: Icons.error_outline,
                      texto: 'Error al leer productos: ${snapshot.error}',
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator(color: _colorAcento)),
                    );
                  }

                  final productos = _filtrar(snapshot.data!);
                  if (productos.isEmpty) {
                    return const _MensajeEstado(
                      icono: Icons.inventory_2_outlined,
                      texto: 'No se encontraron productos.\n'
                          'Carga datos de prueba o crea productos desde el módulo de Productos.',
                    );
                  }

                  return Column(
                    children: productos
                        .map(
                          (producto) => _TarjetaProducto(
                            producto: producto,
                            onTap: () => _abrirDetalle(producto),
                            onCambiarStock: (delta) => _cambioRapido(producto, delta),
                          ),
                        )
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

class _TarjetaProducto extends StatelessWidget {
  final Producto producto;
  final VoidCallback onTap;
  final ValueChanged<int> onCambiarStock;

  const _TarjetaProducto({
    required this.producto,
    required this.onTap,
    required this.onCambiarStock,
  });

  @override
  Widget build(BuildContext context) {
    final bajo = producto.bajoStock;
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
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            producto.nombre,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textoOscuro),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _Etiqueta(
                          texto: bajo ? 'BAJO' : 'STOCK OK',
                          color: bajo ? const Color(0xFFEFA93B) : const Color(0xFF5FA45E),
                          icono: bajo ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${producto.categoria} · ${producto.sucursal} · C\$${producto.precio.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12, color: _textoClaro),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  _BotonRedondo(icono: Icons.remove, onTap: () => onCambiarStock(-1)),
                  SizedBox(
                    width: 34,
                    child: Text(
                      '${producto.stock}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textoOscuro),
                    ),
                  ),
                  _BotonRedondo(icono: Icons.add, onTap: () => onCambiarStock(1), relleno: true),
                ],
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
  final IconData icono;

  const _Etiqueta({required this.texto, required this.color, required this.icono});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 12, color: color),
          const SizedBox(width: 3),
          Text(texto, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _BotonRedondo extends StatelessWidget {
  final IconData icono;
  final VoidCallback onTap;
  final bool relleno;

  const _BotonRedondo({required this.icono, required this.onTap, this.relleno = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: relleno ? _colorAcento : _fondoInput,
          border: Border.all(color: _colorBorde),
        ),
        child: Icon(icono, size: 16, color: relleno ? Colors.white : _textoOscuro),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pantalla de detalle: "Ajustar inventario" (la que se abre al tocar un producto)
// ---------------------------------------------------------------------------

class AjustarInventarioScreen extends StatefulWidget {
  final Producto producto;
  final StockService stockService;

  const AjustarInventarioScreen({
    super.key,
    required this.producto,
    required this.stockService,
  });

  @override
  State<AjustarInventarioScreen> createState() => _AjustarInventarioScreenState();
}

class _AjustarInventarioScreenState extends State<AjustarInventarioScreen> {
  String _tipoAjuste = 'Entrada';
  final TextEditingController _cantidadController = TextEditingController(text: '0');
  final TextEditingController _motivoController = TextEditingController();
  bool _guardando = false;

  int get _cantidad => int.tryParse(_cantidadController.text) ?? 0;

  int get _nuevoStock {
    if (_tipoAjuste == 'Entrada') return widget.producto.stock + _cantidad;
    return widget.producto.stock - _cantidad;
  }

  Future<void> _guardar() async {
    if (_cantidad <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa una cantidad mayor a 0.')),
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      await widget.stockService.ajustarInventario(
        producto: widget.producto,
        tipoAjuste: _tipoAjuste,
        cantidad: _cantidad,
        motivo: _motivoController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el ajuste: $e')),
      );
    }
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    _motivoController.dispose();
    super.dispose();
  }

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
                label: const Text('Stock', style: TextStyle(color: _textoOscuro)),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.producto.nombre,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _textoOscuro),
              ),
              const SizedBox(height: 2),
              Text(
                'Código: ${widget.producto.codigo} · ${widget.producto.categoria} · ${widget.producto.sucursal}',
                style: const TextStyle(fontSize: 12, color: _textoClaro),
              ),
              const SizedBox(height: 18),

              const Text('Stock actual', style: TextStyle(fontSize: 12, color: _textoClaro)),
              const SizedBox(height: 4),
              Text(
                '${widget.producto.stock} unidades',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _textoOscuro),
              ),
              const SizedBox(height: 22),

              const Text(
                'Ajustar inventario',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textoOscuro),
              ),
              const SizedBox(height: 14),

              const Text('Tipo', style: TextStyle(fontSize: 12, color: _textoClaro)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _tipoAjuste,
                items: const [
                  DropdownMenuItem(value: 'Entrada', child: Text('Entrada')),
                  DropdownMenuItem(value: 'Salida', child: Text('Salida')),
                ],
                onChanged: (valor) => setState(() => _tipoAjuste = valor ?? 'Entrada'),
                decoration: _decoracionCampo(),
              ),
              const SizedBox(height: 16),

              const Text('Cantidad', style: TextStyle(fontSize: 12, color: _textoClaro)),
              const SizedBox(height: 6),
              TextField(
                controller: _cantidadController,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: _decoracionCampo(),
              ),
              const SizedBox(height: 16),

              const Text('Motivo', style: TextStyle(fontSize: 12, color: _textoClaro)),
              const SizedBox(height: 6),
              TextField(
                controller: _motivoController,
                decoration: _decoracionCampo(hint: 'Ej. Producción'),
              ),
              const SizedBox(height: 20),

              // Vista previa del nuevo stock
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCEFA0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    const Text('Nuevo Stock', style: TextStyle(fontSize: 12, color: _textoClaro)),
                    const SizedBox(height: 2),
                    Text(
                      '$_nuevoStock unidades',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _textoOscuro),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _guardando ? null : _guardar,
                  icon: _guardando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: const Text('GUARDAR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _colorAcento,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoracionCampo({String? hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: _fondoInput,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _colorBorde),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _colorAcento),
      ),
    );
  }
}
