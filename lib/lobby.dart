import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'Chino/vistas/AppDrawer.dart' show cerrarSesion, ModuloApp;
import 'Chino/controladores/apariencia_service.dart';
import 'Chino/controladores/permisos_service.dart';
import 'Chino/vistas/Auditoria.dart';
import 'Chino/vistas/MateriaPrima.dart';
import 'Henry/vistas/Sucursales.dart';
import 'Chino/vistas/Configuracion.dart';
import 'Chino/vistas/Reportes.dart';
import 'Chino/vistas/SolicitudesPassword.dart' show CampanaSolicitudes;
import 'Chino/vistas/Stock.dart';
import 'Chino/vistas/Usuarios.dart';
import 'Dennis/vistas/productos.dart';
import 'Mauricio/vistas/crud_ventas.dart' show VentasScreen;
import 'Chino/modelos/evento_auditoria_modelo.dart'
    show EventoAuditoria, TipoEvento, colorParaTipoEvento;
import 'services/lobby_service.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({
    super.key,
    this.userName = 'Juan',
  });

  final String userName;

  // Siguen la apariencia elegida en Configuración
  static Color get burgundy => Apariencia.instance.acento;
  static Color get burgundyDark => Apariencia.instance.fondoMenu;

  static Color get bg => Apariencia.instance.fondo;
  static const amber = Color(0xFFD27A0A);
  static Color get textDark => Apariencia.instance.textoPrincipal;

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  int selectedIndex = 0;

  // Datos en vivo de Firestore
  final LobbyService _servicio = LobbyService();
  LobbyDatos _datos = const LobbyDatos();

  bool _servicioActivo = false;

  @override
  void initState() {
    super.initState();
    Permisos.instance.addListener(_alCambiarPermisos);
    Apariencia.instance.addListener(_alCambiarApariencia);
    _sincronizarServicio();
  }

  @override
  void dispose() {
    Permisos.instance.removeListener(_alCambiarPermisos);
    Apariencia.instance.removeListener(_alCambiarApariencia);
    _servicio.detener();
    super.dispose();
  }

  // Solo el admin escucha el panel general
  void _sincronizarServicio() {
    final debeEscuchar = Permisos.instance.puedeVerLobby;
    if (debeEscuchar && !_servicioActivo) {
      _servicioActivo = true;
      _servicio.iniciar((datos) {
        if (mounted) setState(() => _datos = datos);
      });
    } else if (!debeEscuchar && _servicioActivo) {
      _servicioActivo = false;
      _servicio.detener();
      _datos = const LobbyDatos();
    }
  }

  // Repinta el lobby cuando cambian colores o letra
  void _alCambiarApariencia() {
    if (mounted) setState(() {});
  }

  void _alCambiarPermisos() {
    if (!mounted) return;
    setState(_sincronizarServicio);
  }

  // Acceso rápido a nueva venta
  void _nuevaVenta() {
    _abrirModuloChino(const VentasScreen(abrirNuevaVenta: true));
  }

  static const int _indiceVentas = 1;
  static const int _indiceProductos = 2;
  static const int _indiceInventario = 3;
  static const int _indiceReportes = 6;
  static const int _indiceAuditoria = 7;
  static const int _indiceIngredientes = 8;
  static const int _indiceSucursales = 5;
  static const int _indiceUsuarios = 4;
  static const int _indiceConfiguracion = 9;
  // Módulo según el índice del menú
  ModuloApp? _moduloDeIndice(int index) {
    switch (index) {
      case _indiceVentas:
        return ModuloApp.ventas;
      case _indiceProductos:
        return ModuloApp.productos;
      case _indiceInventario:
        return ModuloApp.stock;
      case _indiceReportes:
        return ModuloApp.reportes;
      case _indiceAuditoria:
        return ModuloApp.auditoria;
      case _indiceIngredientes:
        return ModuloApp.materiaPrima;
      case _indiceSucursales:
        return ModuloApp.sucursales;
      case _indiceUsuarios:
        return ModuloApp.usuarios;
    }
    return null;
  }

  void selectSection(int index) {
    // Revisa el rol antes de abrir
    final modulo = _moduloDeIndice(index);
    if (modulo != null && !Permisos.instance.puedeVer(modulo)) {
      avisarSinPermiso(context, 'No tienes permiso para abrir ese módulo.');
      return;
    }

    switch (index) {
      case _indiceVentas:
        _abrirModuloChino(const VentasScreen());
        return;

      case _indiceProductos:
        _abrirModuloChino(const ProductosScreen());
        return;
     
      case _indiceInventario:
        _abrirModuloChino(const StockScreen());
        return;
      case _indiceReportes:
        _abrirModuloChino(const ReportesScreen());
        return;
      case _indiceAuditoria:
        _abrirModuloChino(const AuditoriaScreen());
        return;
      case _indiceIngredientes:
        _abrirModuloChino(const MateriaPrimaScreen());
        return;
      case _indiceSucursales:
        _abrirModuloChino(const SucursalesScreen());
        return;
      case _indiceUsuarios:
        _abrirModuloChino(const UsuariosScreen());
        return;
      case _indiceConfiguracion:
        _abrirModuloChino(const ConfiguracionScreen());
        return;
    }

    setState(() {
      selectedIndex = index;
    });
  }

  // Abrir módulo de Chino
  Future<void> _abrirModuloChino(Widget pantalla) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => pantalla),
    );
    if (mounted) {
      setState(() {
        selectedIndex = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _LobbyScope(
      datos: _datos,
      abrir: selectSection,
      abrirPantalla: _abrirModuloChino,
      nuevaVenta: _nuevaVenta,
      cambiarFiltros: _servicio.aplicarFiltros,
      temaClave:
          '${Apariencia.instance.acentoId}|${Apariencia.instance.fondoId}|'
          '${Apariencia.instance.textoId}',
      child: LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (width < 700) {
          return _MobileLobby(
            userName: widget.userName,
            selectedIndex: selectedIndex,
            onSelected: selectSection,
          );
        }

        if (width < 1050) {
          return _TabletLobby(
            userName: widget.userName,
            selectedIndex: selectedIndex,
            onSelected: selectSection,
          );
        }

        return _DesktopLobby(
          userName: widget.userName,
          selectedIndex: selectedIndex,
          onSelected: selectSection,
        );
      },
      ),
    );
  }
}

// Datos y acciones para las tarjetas
class _LobbyScope extends InheritedWidget {
  const _LobbyScope({
    required this.datos,
    required this.abrir,
    required this.abrirPantalla,
    required this.nuevaVenta,
    required this.cambiarFiltros,
    required this.temaClave,
    required super.child,
  });

  final LobbyDatos datos;

  // Abrir módulo por índice
  final ValueChanged<int> abrir;

  // Abrir cualquier pantalla
  final Future<void> Function(Widget pantalla) abrirPantalla;

  final VoidCallback nuevaVenta;

  // Cambiar filtros del resumen
  final ValueChanged<LobbyFiltros> cambiarFiltros;

  // Cambia cuando se elige otro color o tamaño de letra
  final String temaClave;

  static _LobbyScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_LobbyScope>();
    assert(scope != null, 'Falta _LobbyScope sobre este widget');
    return scope!;
  }

  @override
  bool updateShouldNotify(_LobbyScope old) =>
      datos != old.datos || temaClave != old.temaClave;
}

// Widget con tap y cursor
class _Tocable extends StatelessWidget {
  const _Tocable({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      ),
    );
  }
}

class _AccesoData {
  const _AccesoData(this.icon, this.title, this.subtitle, this.onTap);

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

// Accesos rápidos
List<_AccesoData> _accesosRapidos(_LobbyScope s) {
  final permisos = Permisos.instance;
  final admin = permisos.esAdmin;
  return [
    _AccesoData(Icons.shopping_cart_outlined, 'Nueva venta',
        'Registrar venta', s.nuevaVenta),
    _AccesoData(
        Icons.inventory_2_outlined,
        'Productos',
        admin ? 'Catálogo y stock' : 'Consultar catálogo',
        () => s.abrir(2)),
    _AccesoData(
        Icons.warehouse_outlined,
        'Inventario',
        admin ? 'Ajustar existencias' : 'Stock de tu sucursal',
        () => s.abrir(3)),
    if (!admin)
      _AccesoData(Icons.kitchen_outlined, 'Ingredientes',
          'Consultar ingredientes', () => s.abrir(8)),
    if (permisos.puedeVer(ModuloApp.usuarios))
      _AccesoData(Icons.people_outline, 'Usuarios', 'Personal y roles',
          () => s.abrir(4)),
    if (permisos.puedeVer(ModuloApp.sucursales))
      _AccesoData(Icons.storefront_outlined, 'Sucursales',
          'Puntos de venta', () => s.abrir(5)),
    _AccesoData(
        Icons.bar_chart_outlined,
        'Reportes',
        admin ? 'Generar informes' : 'Tus ventas del día',
        () => s.abrir(6)),
  ];
}

// Altura fija que crece con el tamaño de letra de Configuración
double _esc(BuildContext context, double base) {
  final escalada = MediaQuery.textScalerOf(context).scale(base);
  return escalada > base ? escalada : base;
}

// Pantalla baja (celular de lado): se reducen alturas y márgenes
bool _corto(BuildContext context) => MediaQuery.sizeOf(context).height < 500;

String _saludo() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Buenos días';
  if (h < 19) return 'Buenas tardes';
  return 'Buenas noches';
}

// Formato de moneda
String _fmtMoneda(double v) {
  final f = NumberFormat(v == v.roundToDouble() ? '#,##0' : '#,##0.00');
  return 'C\$ ${f.format(v)}';
}

// Muestra … mientras carga
String _valor(bool cargando, String texto) => cargando ? '…' : texto;

String _fmtHoraEvento(DateTime f) {
  final ahora = DateTime.now();
  final esHoy =
      f.year == ahora.year && f.month == ahora.month && f.day == ahora.day;
  return DateFormat(esHoy ? 'hh:mm a' : 'dd/MM hh:mm a').format(f);
}

IconData _iconoEvento(TipoEvento tipo) {
  switch (tipo) {
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.mensaje);

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Apariencia.instance.errorSuave,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: Apariencia.instance.oscuro
                ? const Color(0xFF6B3A36)
                : const Color(0xFFF3C0BB),
          ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline,
              color: LobbyScreen.burgundy, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensaje,
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                color: LobbyScreen.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Web
class _DesktopLobby extends StatelessWidget {
  const _DesktopLobby({
    required this.userName,
    required this.selectedIndex,
    required this.onSelected,
  });

  final String userName;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LobbyScreen.bg,
      body: Row(
        children: [
          _SideBar(
            compact: false,
            selectedIndex: selectedIndex,
            onSelected: onSelected,
          ),
          Expanded(
            child: _WebDashboard(
              userName: userName,
              desktop: true,
            ),
          ),
        ],
      ),
    );
  }
}

// Tablet
class _TabletLobby extends StatelessWidget {
  const _TabletLobby({
    required this.userName,
    required this.selectedIndex,
    required this.onSelected,
  });

  final String userName;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LobbyScreen.bg,
      body: Row(
        children: [
          _SideBar(
            compact: true,
            selectedIndex: selectedIndex,
            onSelected: onSelected,
          ),
          Expanded(
            child: _WebDashboard(
              userName: userName,
              desktop: false,
            ),
          ),
        ],
      ),
    );
  }
}

// Móvil
class _MobileLobby extends StatelessWidget {
  const _MobileLobby({
    required this.userName,
    required this.selectedIndex,
    required this.onSelected,
  });

  final String userName;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LobbyScreen.bg,
      drawer: _MobileDrawer(
        userName: userName,
        selectedIndex: selectedIndex,
        onSelected: onSelected,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _MobileTopBar(
              userName: userName,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: _corto(context)
                    ? const EdgeInsets.fromLTRB(16, 12, 16, 20)
                    : const EdgeInsets.fromLTRB(16, 20, 16, 30),
                child: _MobileDashboard(
                  userName: userName,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Sidebar Web
class _SideBar extends StatelessWidget {
  const _SideBar({
    required this.compact,
    required this.selectedIndex,
    required this.onSelected,
  });

  final bool compact;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 92 : 250,
      color: Apariencia.instance.oscuro
          ? LobbyScreen.burgundyDark
          : LobbyScreen.burgundy,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 20,
                vertical: _corto(context) ? 8 : 20,
              ),
              child: compact
                  ? CircleAvatar(
                      radius: 22,
                      backgroundColor: Apariencia.instance.superficie,
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/romero.png',
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: Apariencia.instance.superficie,
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/romero.png',
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PANADERÍA',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                'ROMERO',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            const Divider(
              height: 1,
              color: Colors.white24,
            ),
            const SizedBox(height: 14),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
            _SideItem(
              icon: Icons.home_outlined,
              label: 'Inicio',
              compact: compact,
              active: selectedIndex == 0,
              onTap: () => onSelected(0),
            ),
            _SideItem(
              icon: Icons.attach_money,
              label: 'Ventas',
              compact: compact,
              active: selectedIndex == 1,
              onTap: () => onSelected(1),
            ),
            _SideItem(
              icon: Icons.inventory_2_outlined,
              label: 'Productos',
              compact: compact,
              active: selectedIndex == 2,
              onTap: () => onSelected(2),
            ),
            _SideItem(
              icon: Icons.warehouse_outlined,
              label: 'Inventario',
              compact: compact,
              active: selectedIndex == 3,
              onTap: () => onSelected(3),
            ),
            _SideItem(
              icon: Icons.kitchen_outlined,
              label: 'Ingredientes',
              compact: compact,
              active: selectedIndex == 8,
              onTap: () => onSelected(8),
            ),
            if (Permisos.instance.puedeVer(ModuloApp.usuarios))
              _SideItem(
              icon: Icons.people_outline,
              label: 'Usuarios',
              compact: compact,
              active: selectedIndex == 4,
              onTap: () => onSelected(4),
            ),
            if (Permisos.instance.puedeVer(ModuloApp.sucursales))
              _SideItem(
              icon: Icons.storefront_outlined,
              label: 'Sucursales',
              compact: compact,
              active: selectedIndex == 5,
              onTap: () => onSelected(5),
            ),
            _SideItem(
              icon: Icons.bar_chart_outlined,
              label: 'Reportes',
              compact: compact,
              active: selectedIndex == 6,
              onTap: () => onSelected(6),
            ),
            if (Permisos.instance.puedeVer(ModuloApp.auditoria))
              _SideItem(
              icon: Icons.fact_check_outlined,
              label: 'Auditoría',
              compact: compact,
              active: selectedIndex == 7,
              onTap: () => onSelected(7),
            ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 16,
              ),
              child: const Divider(
                color: Colors.white24,
              ),
            ),
            _SideItem(
              icon: Icons.settings_outlined,
              label: 'Configuración',
              compact: compact,
              active: false,
              onTap: () => onSelected(9),
            ),
            _SideItem(
              icon: Icons.logout,
              label: 'Cerrar sesión',
              compact: compact,
              active: false,
              onTap: () => cerrarSesion(context),
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  const _SideItem({
    required this.icon,
    required this.label,
    required this.compact,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool compact;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: _corto(context) ? 2 : 4,
      ),
      child: Material(
        color: active
            ? Colors.white.withOpacity(0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: _esc(context, _corto(context) ? 38 : 46),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 0 : 14,
            ),
            child: Row(
              mainAxisAlignment: compact
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 19,
                ),
                if (!compact) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight:
                            active ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Contenido Web
class _WebDashboard extends StatelessWidget {
  const _WebDashboard({
    required this.userName,
    required this.desktop,
  });

  final String userName;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      left: false,
      top: false,
      child: Column(
      children: [
        _WebTopBar(
          userName: userName,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(
              _corto(context) ? 14 : (desktop ? 28 : 20),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 1280,
                ),
                child: _WebDashboardBody(
                  desktop: desktop,
                  userName: userName,
                ),
              ),
            ),
          ),
        ),
      ],
      ),
    );
  }
}

class _WebTopBar extends StatelessWidget {
  const _WebTopBar({
    required this.userName,
  });

  final String userName;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _corto(context) ? 56 : 76,
      padding: const EdgeInsets.symmetric(
        horizontal: 28,
      ),
      decoration: BoxDecoration(
        color: Apariencia.instance.superficie,
        border: Border(
          bottom: BorderSide(
            color: Apariencia.instance.bordeSuave,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Lobby',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: LobbyScreen.textDark,
              ),
            ),
          ),
          const CampanaSolicitudes(),
          const SizedBox(width: 8),
          _MenuCuenta(userName: userName, conNombre: true),
        ],
      ),
    );
  }
}

class _WebDashboardBody extends StatelessWidget {
  const _WebDashboardBody({
    required this.desktop,
    required this.userName,
  });

  final bool desktop;
  final String userName;

  @override
  Widget build(BuildContext context) {
    final scope = _LobbyScope.of(context);
    final d = scope.datos;
    final corto = _corto(context);

    final tarjetas = <Widget>[
      _WebSummaryCard(
        compacto: corto,
        value: _valor(d.cargandoVentas, _fmtMoneda(d.ingresosHoy)),
        label: 'Ingresos',
        color: LobbyScreen.burgundy,
        onTap: () => scope.abrir(1),
      ),
      _WebSummaryCard(
        compacto: corto,
        value: _valor(d.cargandoVentas, '${d.ventasHoy}'),
        label: 'Ventas',
        color: LobbyScreen.burgundy,
        onTap: () => scope.abrir(1),
      ),
      _WebSummaryCard(
        compacto: corto,
        value: _valor(d.cargandoProductos, '${d.stockBajo.length}'),
        label: 'Stock bajo',
        color: LobbyScreen.amber,
        onTap: () => scope.abrir(3),
      ),
    ];

    final accesos = _accesosRapidos(scope);
    // Panel general solo para admin
    final verPanel = Permisos.instance.puedeVerLobby;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_saludo()}, $userName',
          style: TextStyle(
            fontSize: corto ? 20 : 28,
            fontWeight: FontWeight.w900,
            color: LobbyScreen.textDark,
          ),
        ),
        if (d.error != null) ...[
          const SizedBox(height: 14),
          _ErrorBanner(d.error!),
        ],
        if (verPanel) ...[
        SizedBox(height: corto ? 14 : 24),
        const _EncabezadoResumen(),
        SizedBox(height: corto ? 10 : 14),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 480) {
              return Row(
                children: [
                  Expanded(child: tarjetas[0]),
                  const SizedBox(width: 16),
                  Expanded(child: tarjetas[1]),
                  const SizedBox(width: 16),
                  Expanded(child: tarjetas[2]),
                ],
              );
            }

            return Column(
              children: [
                tarjetas[0],
                const SizedBox(height: 12),
                tarjetas[1],
                const SizedBox(height: 12),
                tarjetas[2],
              ],
            );
          },
        ),
        ],
        const SizedBox(height: 30),
        const _SectionTitle(
          title: 'ACCESOS RÁPIDOS',
        ),
        const SizedBox(height: 14),
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 360,
            mainAxisExtent: _esc(context, corto ? 64 : 76),
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          children: [
            for (final a in accesos)
              _WebQuickCard(
                compacto: corto,
                icon: a.icon,
                title: a.title,
                subtitle: a.subtitle,
                onTap: a.onTap,
              ),
          ],
        ),
        if (verPanel) ...[
        const SizedBox(height: 24),
        if (desktop)
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _StockAlert(),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _RecentActivity(),
              ),
            ],
          )
        else ...[
          const _StockAlert(),
          const SizedBox(height: 14),
          const _RecentActivity(),
        ],
        ],
        const SizedBox(height: 20),
      ],
    );
  }
}

class _WebSummaryCard extends StatelessWidget {
  const _WebSummaryCard({
    required this.value,
    required this.label,
    required this.color,
    this.onTap,
    this.compacto = false,
  });

  final String value;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final tarjeta = _tarjeta(context);
    return onTap == null ? tarjeta : _Tocable(onTap: onTap!, child: tarjeta);
  }

  Widget _tarjeta(BuildContext context) {
    return Container(
      height: _esc(context, compacto ? 84 : 116),
      padding: EdgeInsets.all(compacto ? 12 : 20),
      decoration: BoxDecoration(
        color: Apariencia.instance.superficie,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Apariencia.instance.bordeSuave,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: compacto ? 22 : 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Apariencia.instance.textoClaro,
            ),
          ),
        ],
      ),
    );
  }
}

class _WebQuickCard extends StatelessWidget {
  const _WebQuickCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.compacto = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Apariencia.instance.superficie,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(compacto ? 8 : 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Apariencia.instance.bordeSuave,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: LobbyScreen.burgundy.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: LobbyScreen.burgundy,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: Apariencia.instance.textoClaro,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Apariencia.instance.hint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Barra superior móvil
class _MobileTopBar extends StatelessWidget {
  const _MobileTopBar({
    required this.userName,
  });

  final String userName;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _corto(context) ? 56 : 68,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
      ),
      decoration: BoxDecoration(
        color: Apariencia.instance.superficie,
        border: Border(
          bottom: BorderSide(
            color: Apariencia.instance.bordeSuave,
          ),
        ),
      ),
      child: Row(
        children: [
          Builder(
            builder: (context) {
              return Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: LobbyScreen.burgundy.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                  icon: Icon(
                    Icons.menu_rounded,
                    color: LobbyScreen.burgundy,
                    size: 24,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 19,
            backgroundColor: Apariencia.instance.superficie,
            child: ClipOval(
              child: Image.asset(
                'assets/images/romero.png',
                width: 38,
                height: 38,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PANADERÍA ROMERO',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: LobbyScreen.textDark,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Panel principal',
                  style: TextStyle(
                    fontSize: 9,
                    color: Apariencia.instance.textoClaro,
                  ),
                ),
              ],
            ),
          ),
          const CampanaSolicitudes(
            iconSize: 21,
            constraints: BoxConstraints(
              minWidth: 38,
              minHeight: 38,
            ),
          ),
          _MenuCuenta(userName: userName),
        ],
      ),
    );
  }
}

// Menú móvil
class _MobileDrawer extends StatelessWidget {
  const _MobileDrawer({
    required this.userName,
    required this.selectedIndex,
    required this.onSelected,
  });

  final String userName;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  void select(
    BuildContext context,
    int index,
  ) {
    // Cierra el drawer antes de navegar
    Navigator.pop(context);
    onSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Drawer(
      width: width * 0.84,
      backgroundColor: LobbyScreen.burgundyDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                18,
                20,
                10,
                16,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Apariencia.instance.superficie,
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/romero.png',
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PANADERÍA ROMERO',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
           
            const Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                22,
                20,
                8,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'MENÚ PRINCIPAL',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(
                  bottom: 10,
                ),
                child: Column(
                  children: [
                    _DrawerItem(
                      icon: Icons.dashboard_outlined,
                      title: 'Inicio',
                      active: selectedIndex == 0,
                      onTap: () {
                        select(context, 0);
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.point_of_sale_outlined,
                      title: 'Ventas',
                      active: selectedIndex == 1,
                      onTap: () {
                        select(context, 1);
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.inventory_2_outlined,
                      title: 'Productos',
                      active: selectedIndex == 2,
                      onTap: () {
                        select(context, 2);
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.warehouse_outlined,
                      title: 'Inventario',
                      active: selectedIndex == 3,
                      onTap: () {
                        select(context, 3);
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.kitchen_outlined,
                      title: 'Ingredientes',
                      active: selectedIndex == 8,
                      onTap: () {
                        select(context, 8);
                      },
                    ),
                    if (Permisos.instance.puedeVer(ModuloApp.usuarios))
                      _DrawerItem(
                      icon: Icons.people_outline,
                      title: 'Usuarios',
                      active: selectedIndex == 4,
                      onTap: () {
                        select(context, 4);
                      },
                    ),
                    if (Permisos.instance.puedeVer(ModuloApp.sucursales))
                      _DrawerItem(
                      icon: Icons.storefront_outlined,
                      title: 'Sucursales',
                      active: selectedIndex == 5,
                      onTap: () {
                        select(context, 5);
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.bar_chart_outlined,
                      title: 'Reportes',
                      active: selectedIndex == 6,
                      onTap: () {
                        select(context, 6);
                      },
                    ),
                    if (Permisos.instance.puedeVer(ModuloApp.auditoria))
                      _DrawerItem(
                      icon: Icons.fact_check_outlined,
                      title: 'Auditoría',
                      active: selectedIndex == 7,
                      onTap: () {
                        select(context, 7);
                      },
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
              ),
              child: Divider(
                color: Colors.white.withOpacity(0.15),
              ),
            ),
            _DrawerItem(
              icon: Icons.settings_outlined,
              title: 'Configuración',
              active: false,
              onTap: () => select(context, 9),
            ),
            _DrawerItem(
              icon: Icons.logout_rounded,
              title: 'Cerrar sesión',
              active: false,
              onTap: () => cerrarSesion(context),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 3,
      ),
      child: Material(
        color: active
            ? Colors.white.withOpacity(0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.white.withOpacity(0.15)
                        : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 19,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight:
                          active ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                if (active)
                  const Icon(
                    Icons.chevron_right,
                    color: Colors.white70,
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Dashboard móvil
class _MobileDashboard extends StatelessWidget {
  const _MobileDashboard({
    required this.userName,
  });

  final String userName;

  @override
  Widget build(BuildContext context) {
    final scope = _LobbyScope.of(context);
    final d = scope.datos;
    final accesos = _accesosRapidos(scope);
    // Panel general solo para admin
    final verPanel = Permisos.instance.puedeVerLobby;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_saludo()}, $userName',
          style: TextStyle(
            fontSize: _corto(context) ? 19 : 23,
            fontWeight: FontWeight.w900,
            color: LobbyScreen.textDark,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          verPanel
              ? 'Aquí tienes el resumen de Panadería Romero.'
              : 'Estos son tus accesos en Panadería Romero.',
          style: TextStyle(
            fontSize: 11,
            color: Apariencia.instance.textoClaro,
          ),
        ),
        if (d.error != null) ...[
          const SizedBox(height: 14),
          _ErrorBanner(d.error!),
        ],
        if (verPanel) ...[
        SizedBox(height: _corto(context) ? 14 : 24),
        const _EncabezadoResumen(),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, box) {
            final ingresos =
                _valor(d.cargandoVentas, _fmtMoneda(d.ingresosHoy));
            final ventas = _valor(d.cargandoVentas, '${d.ventasHoy}');
            final bajo =
                _valor(d.cargandoProductos, '${d.stockBajo.length}');

            // Celular de lado: las tres tarjetas en una fila
            if (box.maxWidth >= 520) {
              return Row(
                children: [
                  Expanded(
                    child: _WebSummaryCard(
                      compacto: true,
                      value: ingresos,
                      label: 'Ingresos',
                      color: LobbyScreen.burgundy,
                      onTap: () => scope.abrir(1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _WebSummaryCard(
                      compacto: true,
                      value: ventas,
                      label: 'Ventas',
                      color: LobbyScreen.burgundy,
                      onTap: () => scope.abrir(1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _WebSummaryCard(
                      compacto: true,
                      value: bajo,
                      label: 'Stock bajo',
                      color: LobbyScreen.amber,
                      onTap: () => scope.abrir(3),
                    ),
                  ),
                ],
              );
            }

            return Column(
              children: [
                _MobileIncomeCard(
                  label:
                      'Ingresos · ${d.filtros.periodo.etiqueta.toLowerCase()}',
                  value: ingresos,
                  onTap: () => scope.abrir(1),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _MobileMetricCard(
                        icon: Icons.receipt_long_outlined,
                        value: ventas,
                        label: 'Ventas',
                        color: LobbyScreen.burgundy,
                        onTap: () => scope.abrir(1),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MobileMetricCard(
                        icon: Icons.warning_amber_rounded,
                        value: bajo,
                        label: 'Stock bajo',
                        color: LobbyScreen.amber,
                        onTap: () => scope.abrir(3),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        ],
        const SizedBox(height: 26),
        const _SectionTitle(
          title: 'ACCESOS RÁPIDOS',
        ),
        const SizedBox(height: 12),
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 420,
            mainAxisExtent: _esc(context, 72),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          children: [
            for (final a in accesos)
              _MobileQuickCard(
                icon: a.icon,
                title: a.title,
                subtitle: a.subtitle,
                onTap: a.onTap,
              ),
          ],
        ),
        if (verPanel) ...[
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, box) {
            if (box.maxWidth >= 600) {
              return const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _StockAlert()),
                  SizedBox(width: 12),
                  Expanded(child: _RecentActivity()),
                ],
              );
            }
            return const Column(
              children: [
                _StockAlert(),
                SizedBox(height: 12),
                _RecentActivity(),
              ],
            );
          },
        ),
        ],

      ],
    );
  }
}

class _MobileIncomeCard extends StatelessWidget {
  const _MobileIncomeCard({
    required this.value,
    required this.onTap,
    this.label = 'Ingresos de hoy',
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Tocable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Apariencia.instance.superficie,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: Apariencia.instance.bordeSuave,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: LobbyScreen.burgundy.withOpacity(0.08),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                Icons.payments_outlined,
                color: LobbyScreen.burgundy,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: LobbyScreen.burgundy,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Apariencia.instance.textoClaro,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileMetricCard extends StatelessWidget {
  const _MobileMetricCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Tocable(
      onTap: onTap,
      child: Container(
        height: _esc(context, 126),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Apariencia.instance.superficie,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Apariencia.instance.bordeSuave,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: color,
              size: 21,
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: Apariencia.instance.textoClaro,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileQuickCard extends StatelessWidget {
  const _MobileQuickCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Apariencia.instance.superficie,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(
            minHeight: 72,
          ),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Apariencia.instance.bordeSuave,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: LobbyScreen.burgundy.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  color: LobbyScreen.burgundy,
                  size: 21,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: LobbyScreen.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Apariencia.instance.textoClaro,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: Apariencia.instance.hint,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: LobbyScreen.textDark,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _StockAlert extends StatelessWidget {
  const _StockAlert();

  @override
  Widget build(BuildContext context) {
    final scope = _LobbyScope.of(context);
    final d = scope.datos;

    // Sin alertas mientras cargan los productos
    if (d.cargandoProductos) return const SizedBox.shrink();

    final bajos = d.stockBajo;
    final enOrden = bajos.isEmpty;
    final color = enOrden ? const Color(0xFF2E7D32) : LobbyScreen.amber;

    final titulo = enOrden ? 'Inventario en orden' : 'Inventario bajo';
    final detalle = enOrden
        ? 'Ningún producto está en su stock mínimo'
        : (bajos.length == 1
            ? '1 producto necesita reposición'
            : '${bajos.length} productos necesitan reposición');

    // Los 3 más críticos
    final nombres = bajos
        .take(3)
        .map((p) => '${p.nombre} (${p.stock}/${p.stockMinimo})')
        .join(', ');
    final resto = bajos.length > 3 ? ' y ${bajos.length - 3} más' : '';

    return _Tocable(
      onTap: () => scope.abrir(3),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: enOrden
            ? Apariencia.instance.exitoSuave
            : Apariencia.instance.aviso,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              enOrden
                  ? Icons.check_circle_outline
                  : Icons.warning_amber_rounded,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detalle,
                    style: TextStyle(
                      fontSize: 10,
                      color: LobbyScreen.textDark,
                    ),
                  ),
                  if (!enOrden) ...[
                    const SizedBox(height: 4),
                    Text(
                      '$nombres$resto',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.4,
                        color: Apariencia.instance.textoClaro,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity();

  @override
  Widget build(BuildContext context) {
    final scope = _LobbyScope.of(context);
    final d = scope.datos;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Apariencia.instance.superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Apariencia.instance.bordeSuave,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Actividad reciente',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _Tocable(
                onTap: () => scope.abrir(7),
                child: Text(
                  'Ver todo →',
                  style: TextStyle(
                    fontSize: 10,
                    color: LobbyScreen.burgundy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (d.cargandoActividad)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (d.actividad.isEmpty)
            Text(
              'Todavía no hay actividad registrada.',
              style: TextStyle(fontSize: 10, color: Apariencia.instance.textoClaro),
            )
          else
            for (final e in d.actividad)
              _FilaActividad(
                evento: e,
                onTap: () => scope.abrirPantalla(
                  DetalleEventoScreen(evento: e),
                ),
              ),
        ],
      ),
    );
  }
}

class _FilaActividad extends StatelessWidget {
  const _FilaActividad({required this.evento, required this.onTap});

  final EventoAuditoria evento;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = colorParaTipoEvento(evento.tipo);
    final partes = <String>[
      if (evento.autor.trim().isNotEmpty) evento.autor.trim(),
      if (evento.modulo.trim().isNotEmpty) evento.modulo.trim(),
      _fmtHoraEvento(evento.fecha),
    ];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withOpacity(0.14),
              child: Icon(
                _iconoEvento(evento.tipo),
                color: color,
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    evento.descripcion.trim().isEmpty
                        ? evento.titulo
                        : evento.descripcion,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: LobbyScreen.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    partes.join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: Apariencia.instance.textoClaro,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, size: 16, color: Apariencia.instance.hint),
          ],
        ),
      ),
    );
  }
}

String _initials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .toList();

  if (parts.isEmpty) {
    return 'U';
  }

  return parts
      .take(2)
      .map((e) => e[0].toUpperCase())
      .join();
}

// Título del resumen + filtros (una fila ancha o dos filas angostas)
class _EncabezadoResumen extends StatelessWidget {
  const _EncabezadoResumen();

  @override
  Widget build(BuildContext context) {
    final f = _LobbyScope.of(context).datos.filtros;
    final titulo = _SectionTitle(
      title: 'RESUMEN · ${f.periodo.etiqueta.toUpperCase()}'
          '${f.sucursal.isEmpty ? '' : ' · ${f.sucursal.toUpperCase()}'}',
    );

    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth >= 640) {
          return Row(
            children: [
              Flexible(child: titulo),
              const SizedBox(width: 16),
              const Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _FiltrosLobby(),
                ),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titulo,
            const SizedBox(height: 8),
            const _FiltrosLobby(),
          ],
        );
      },
    );
  }
}

// Desplegables: sucursal y periodo
class _FiltrosLobby extends StatelessWidget {
  const _FiltrosLobby();

  @override
  Widget build(BuildContext context) {
    final scope = _LobbyScope.of(context);
    final d = scope.datos;
    final f = d.filtros;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _FiltroDesplegable(
          icono: Icons.storefront_outlined,
          tooltip: 'Sucursal',
          valor: f.sucursal,
          activo: f.sucursal.isNotEmpty,
          opciones: {
            '': 'Todas',
            for (final s in d.sucursales) s: s,
          },
          onChanged: (v) => scope.cambiarFiltros(f.copyWith(sucursal: v)),
        ),
        _FiltroDesplegable(
          icono: Icons.calendar_today_outlined,
          tooltip: 'Periodo',
          valor: f.periodo.name,
          activo: f.periodo != PeriodoLobby.hoy,
          opciones: {
            for (final p in PeriodoLobby.values) p.name: p.etiqueta,
          },
          onChanged: (v) => scope.cambiarFiltros(
            f.copyWith(periodo: PeriodoLobby.values.byName(v)),
          ),
        ),
        if (!f.esPorDefecto)
          Tooltip(
            message: 'Quitar filtros',
            child: _Tocable(
              onTap: () => scope.cambiarFiltros(const LobbyFiltros()),
              child: SizedBox(
                width: 32,
                height: 36,
                child: Icon(
                  Icons.filter_alt_off_outlined,
                  size: 20,
                  color: LobbyScreen.burgundy,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// Desplegable compacto: icono + valor
class _FiltroDesplegable extends StatelessWidget {
  const _FiltroDesplegable({
    required this.icono,
    required this.tooltip,
    required this.valor,
    required this.activo,
    required this.opciones,
    required this.onChanged,
  });

  final IconData icono;
  final String tooltip;
  final String valor;
  final bool activo;

  // clave -> texto (la primera es la opción por defecto)
  final Map<String, String> opciones;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    // Si el valor ya no existe en la lista, se muestra la primera
    final actual = opciones.containsKey(valor) ? valor : opciones.keys.first;

    return Tooltip(
      message: tooltip,
      child: Container(
        height: _esc(context, 36),
        padding: const EdgeInsets.only(left: 10, right: 6),
        decoration: BoxDecoration(
          color: Apariencia.instance.superficie,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: activo
                ? LobbyScreen.burgundy.withOpacity(0.55)
                : Apariencia.instance.borde,
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: actual,
            isDense: true,
            borderRadius: BorderRadius.circular(12),
            dropdownColor: Apariencia.instance.superficie,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: Apariencia.instance.textoClaro,
            ),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: LobbyScreen.textDark,
            ),
            selectedItemBuilder: (_) => [
              for (final e in opciones.entries)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icono, size: 16, color: LobbyScreen.burgundy),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 110),
                      child: Text(
                        e.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
            ],
            items: [
              for (final e in opciones.entries)
                DropdownMenuItem<String>(
                  value: e.key,
                  child: Text(e.value),
                ),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ),
    );
  }
}

// Círculo de la cuenta: abre un menú con los datos del usuario
class _MenuCuenta extends StatelessWidget {
  const _MenuCuenta({required this.userName, this.conNombre = false});

  final String userName;
  final bool conNombre;

  static String _rol() {
    final p = Permisos.instance;
    if (p.esAdmin) return 'Administrador';
    return p.esEncargado ? 'Encargado' : 'Vendedor';
  }

  @override
  Widget build(BuildContext context) {
    final scope = _LobbyScope.of(context);
    final p = Permisos.instance;
    final detalle = [
      _rol(),
      if (p.sucursal.isNotEmpty) p.sucursal,
    ].join(' · ');

    final avatar = CircleAvatar(
      radius: conNombre ? 19 : 18,
      backgroundColor: LobbyScreen.burgundy,
      child: Text(
        _initials(userName),
        style: TextStyle(
          color: Colors.white,
          fontSize: conNombre ? 14 : 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    return PopupMenuButton<String>(
      tooltip: 'Mi cuenta',
      padding: EdgeInsets.zero,
      offset: const Offset(0, 46),
      color: Apariencia.instance.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (valor) {
        if (valor == 'config') {
          scope.abrir(_LobbyScreenState._indiceConfiguracion);
        } else if (valor == 'salir') {
          cerrarSesion(context);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                userName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: LobbyScreen.textDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detalle,
                style: TextStyle(fontSize: 12, color: Apariencia.instance.textoClaro),
              ),
              if (p.correo.isNotEmpty)
                Text(
                  p.correo,
                  style: TextStyle(fontSize: 11, color: Apariencia.instance.hint),
                ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'config',
          child: Row(
            children: [
              Icon(Icons.settings_outlined, size: 19),
              SizedBox(width: 10),
              Text('Configuración'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'salir',
          child: Row(
            children: [
              Icon(Icons.logout, size: 19),
              SizedBox(width: 10),
              Text('Cerrar sesión'),
            ],
          ),
        ),
      ],
      child: conNombre
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                avatar,
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: LobbyScreen.textDark,
                    ),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: Apariencia.instance.textoClaro),
              ],
            )
          : avatar,
    );
  }
}