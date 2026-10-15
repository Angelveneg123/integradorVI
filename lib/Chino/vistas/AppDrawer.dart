import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'Stock.dart';
import 'Auditoria.dart';
import 'Reportes.dart';
import 'MateriaPrima.dart';
import 'Usuarios.dart';
import 'Configuracion.dart';
import '../controladores/permisos_service.dart';
import '../../Henry/vistas/Sucursales.dart';
import '../../Dennis/vistas/productos.dart';
import '../../Mauricio/vistas/crud_ventas.dart' show VentasScreen;

// Colores del lobby
const Color _burgundy = Color(0xFF8D141B);
const Color _burgundyDark = Color(0xFF681015);
const Color _textDark = Color(0xFF2E2927);

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
                    backgroundColor: Colors.white,
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/romero.jpeg',
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(
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
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFECE5E0)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF5EEEE),
              borderRadius: BorderRadius.circular(11),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: () => scaffoldKey.currentState?.openDrawer(),
              icon: const Icon(
                Icons.menu_rounded,
                color: _burgundy,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 19,
            backgroundColor: Colors.white,
            child: ClipOval(
              child: Image.asset(
                'assets/images/romero.jpeg',
                width: 38,
                height: 38,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
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
                const Text(
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
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            constraints: const BoxConstraints(
              minWidth: 38,
              minHeight: 38,
            ),
            icon: const Icon(
              Icons.notifications_none_rounded,
              size: 21,
              color: _textDark,
            ),
          ),
        ],
      ),
    );
  }
}