import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'Stock.dart';
import 'Auditoria.dart';
import 'Reportes.dart';
import 'MateriaPrima.dart';
import 'Usuarios.dart';
import 'Configuracion.dart';
import 'SolicitudesPassword.dart' show CampanaSolicitudes;
import '../controladores/permisos_service.dart';
import '../../Henry/vistas/Sucursales.dart';
import '../../Dennis/vistas/productos.dart';
import '../../Mauricio/vistas/crud_ventas.dart' show VentasScreen;
import '../controladores/apariencia_service.dart';

// Colores del lobby
Color get _burgundy => Apariencia.instance.acento;
Color get _burgundyDark => Apariencia.instance.fondoMenu;

Color get _textDark => Apariencia.instance.textoPrincipal;

// Cerrar sesión
Future<void> cerrarSesion(BuildContext context) async {
  final navigator = Navigator.of(context, rootNavigator: true);

  final confirmar = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Cerrar sesión'),
      content: const Text('¿Seguro que quieres salir de tu cuenta?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: TextButton.styleFrom(foregroundColor: _burgundy),
          child: const Text('Salir'),
        ),
      ],
    ),
  );

  if (confirmar != true) return;

  // Cierra todo hasta la raíz
  navigator.popUntil((route) => route.isFirst);

  await FirebaseAuth.instance.signOut();
}

// Módulo activo en el menú
enum ModuloApp {
  ventas,
  productos,
  stock,
  materiaPrima,
  usuarios,
  sucursales,
  auditoria,
  reportes,
}

// Menú lateral de los módulos
class AppDrawer extends StatelessWidget {
  final ModuloApp moduloActual;

  const AppDrawer({super.key, required this.moduloActual});

  void _irA(BuildContext context, ModuloApp modulo) {
    Navigator.pop(context); // cierra la barra lateral
    if (modulo == moduloActual) return; // ya estás en ese módulo

    // Revisa el rol
    if (!Permisos.instance.puedeVer(modulo)) {
      avisarSinPermiso(context, 'No tienes permiso para abrir ese módulo.');
      return;
    }

    final Widget pantalla = switch (modulo) {
      ModuloApp.ventas => const VentasScreen(),
      ModuloApp.productos => const ProductosScreen(),
      ModuloApp.stock => const StockScreen(),
      ModuloApp.materiaPrima => const MateriaPrimaScreen(),
      ModuloApp.usuarios => const UsuariosScreen(),
      ModuloApp.sucursales => const SucursalesScreen(),
      ModuloApp.auditoria => const AuditoriaScreen(),
      ModuloApp.reportes => const ReportesScreen(),
    };

    // Reemplaza la pantalla actual
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => pantalla),
    );
  }

  // Abrir configuración
  void _abrirConfiguracion(BuildContext context) {
    Navigator.pop(context); // cierra la barra lateral
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ConfiguracionScreen()),
    );
  }

  // Volver al lobby
  void _volverAlLobby(BuildContext context) {
    Navigator.pop(context); // cierra la barra lateral
    Navigator.of(context).pop(); // regresa al Lobby
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Drawer(
      width: width * 0.84,
      backgroundColor: _burgundyDark,
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
              padding: const EdgeInsets.fromLTRB(18, 20, 10, 16),
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
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.bakery_dining,
                          color: _burgundy,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PANADERÍA ROMERO',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Gestión de operaciones',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFFE6C6C8),
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
              padding: EdgeInsets.fromLTRB(20, 22, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'MENÚ PRINCIPAL',
                  style: TextStyle(
                    color: Color(0xFFDAB7B9),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  children: [
                    _DrawerItem(
                      icon: Icons.dashboard_outlined,
                      title: 'Inicio',
                      active: false,
                      onTap: () => _volverAlLobby(context),
                    ),
                    _DrawerItem(
                      icon: Icons.point_of_sale_outlined,
                      title: 'Ventas',
                      active: moduloActual == ModuloApp.ventas,
                      onTap: () => _irA(context, ModuloApp.ventas),
                    ),
                    _DrawerItem(
                      icon: Icons.inventory_2_outlined,
                      title: 'Productos',
                      active: moduloActual == ModuloApp.productos,
                      onTap: () => _irA(context, ModuloApp.productos),
                    ),
                    _DrawerItem(
                      icon: Icons.warehouse_outlined,
                      title: 'Inventario',
                      active: moduloActual == ModuloApp.stock,
                      onTap: () => _irA(context, ModuloApp.stock),
                    ),
                    _DrawerItem(
                      icon: Icons.kitchen_outlined,
                      title: 'Ingredientes',
                      active: moduloActual == ModuloApp.materiaPrima,
                      onTap: () => _irA(context, ModuloApp.materiaPrima),
                    ),
                    if (Permisos.instance.puedeVer(ModuloApp.usuarios))
                      _DrawerItem(
                        icon: Icons.people_outline,
                        title: 'Usuarios',
                        active: moduloActual == ModuloApp.usuarios,
                        onTap: () => _irA(context, ModuloApp.usuarios),
                      ),
                    if (Permisos.instance.puedeVer(ModuloApp.sucursales))
                      _DrawerItem(
                        icon: Icons.storefront_outlined,
                        title: 'Sucursales',
                        active: moduloActual == ModuloApp.sucursales,
                        onTap: () => _irA(context, ModuloApp.sucursales),
                      ),
                    _DrawerItem(
                      icon: Icons.bar_chart_outlined,
                      title: 'Reportes',
                      active: moduloActual == ModuloApp.reportes,
                      onTap: () => _irA(context, ModuloApp.reportes),
                    ),
                    if (Permisos.instance.puedeVer(ModuloApp.auditoria))
                      _DrawerItem(
                        icon: Icons.fact_check_outlined,
                        title: 'Auditoría',
                        active: moduloActual == ModuloApp.auditoria,
                        onTap: () => _irA(context, ModuloApp.auditoria),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Divider(
                color: Colors.white.withOpacity(0.15),
              ),
            ),
            _DrawerItem(
              icon: Icons.settings_outlined,
              title: 'Configuración',
              active: false,
              onTap: () => _abrirConfiguracion(context),
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
            padding: const EdgeInsets.symmetric(horizontal: 12),
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

// Barra superior de los módulos
class ChinoTopBar extends StatelessWidget {
  const ChinoTopBar({
    super.key,
    required this.scaffoldKey,
    required this.subtitulo,
  });

  final GlobalKey<ScaffoldState> scaffoldKey;
  final String subtitulo;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Apariencia.instance.superficie,
        border: Border(
          bottom: BorderSide(color: Apariencia.instance.bordeSuave),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Apariencia.instance.acentoSuave,
              borderRadius: BorderRadius.circular(11),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: () => scaffoldKey.currentState?.openDrawer(),
              icon: Icon(
                Icons.menu_rounded,
                color: _burgundy,
                size: 24,
              ),
            ),
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
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.bakery_dining,
                  color: _burgundy,
                  size: 20,
                ),
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
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    color: Apariencia.instance.textoClaro,
                  ),
                ),
              ],
            ),
          ),
          // Campana: solo la ve el admin
          const CampanaSolicitudes(
            iconSize: 21,
            constraints: BoxConstraints(
              minWidth: 38,
              minHeight: 38,
            ),
          ),
          const SizedBox(width: 4),
          // Círculo de la cuenta (igual que en el lobby)
          const MenuCuentaModulo(),
        ],
      ),
    );
  }
}

// Círculo con la inicial: abre un menú con los datos de la cuenta
class MenuCuentaModulo extends StatelessWidget {
  const MenuCuentaModulo({super.key});

  static String _rol() {
    final p = Permisos.instance;
    if (p.esAdmin) return 'Administrador';
    return p.esEncargado ? 'Encargado' : 'Vendedor';
  }

  // Mismo nombre que se muestra en el lobby (primer nombre)
  static String _nombre() {
    final p = Permisos.instance;
    if (p.nombre.isNotEmpty) return p.nombre.split(' ').first;
    final user = FirebaseAuth.instance.currentUser;
    final display = user?.displayName?.trim() ?? '';
    if (display.isNotEmpty) return display;
    final correo = user?.email ?? '';
    return correo.isNotEmpty ? correo.split('@').first : 'Usuario';
  }

  static String _iniciales(String valor) {
    final partes = valor
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (partes.isEmpty) return 'U';
    return partes.take(2).map((e) => e[0].toUpperCase()).join();
  }

  void _abrirConfiguracion(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ConfiguracionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Permisos.instance,
      builder: (context, _) {
        final p = Permisos.instance;
        final nombre = _nombre();
        final detalle = [
          _rol(),
          if (p.sucursal.isNotEmpty) p.sucursal,
        ].join(' · ');

        return PopupMenuButton<String>(
          tooltip: 'Mi cuenta',
          padding: EdgeInsets.zero,
          offset: const Offset(0, 46),
          color: Apariencia.instance.superficie,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          onSelected: (valor) {
            if (valor == 'config') {
              _abrirConfiguracion(context);
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
                    nombre,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detalle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Apariencia.instance.textoClaro,
                    ),
                  ),
                  if (p.correo.isNotEmpty)
                    Text(
                      p.correo,
                      style: TextStyle(
                        fontSize: 11,
                        color: Apariencia.instance.hint,
                      ),
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
          child: CircleAvatar(
            radius: 18,
            backgroundColor: _burgundy,
            child: Text(
              _iniciales(nombre),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );
      },
    );
  }
}