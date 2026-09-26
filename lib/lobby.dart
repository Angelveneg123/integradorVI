import 'package:flutter/material.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({
    super.key,
    this.userName = 'Juan',
  });

  final String userName;

  static const burgundy = Color(0xFF8D141B);
  static const burgundyDark = Color(0xFF681015);
  static const bg = Color(0xFFFAF6EE);
  static const amber = Color(0xFFD27A0A);
  static const textDark = Color(0xFF2E2927);

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  int selectedIndex = 0;

  void selectSection(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
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
                padding: const EdgeInsets.fromLTRB(
                  16,
                  20,
                  16,
                  30,
                ),
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
      color: LobbyScreen.burgundy,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 20,
                vertical: 20,
              ),
              child: compact
                  ? CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white,
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/romero.jpeg',
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
                          backgroundColor: Colors.white,
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/romero.jpeg',
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
                                  color: Color(0xFFE6C5C7),
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
              color: Color(0xFFAA454A),
            ),
            const SizedBox(height: 14),
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
              icon: Icons.people_outline,
              label: 'Usuarios',
              compact: compact,
              active: selectedIndex == 4,
              onTap: () => onSelected(4),
            ),
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
            const Spacer(),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 16,
              ),
              child: const Divider(
                color: Color(0xFFAA454A),
              ),
            ),
            _SideItem(
              icon: Icons.settings_outlined,
              label: 'Configuración',
              compact: compact,
              active: false,
              onTap: () {},
            ),
            _SideItem(
              icon: Icons.logout,
              label: 'Cerrar sesión',
              compact: compact,
              active: false,
              onTap: () {},
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
        vertical: 4,
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
            height: 46,
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
    return Column(
      children: [
        _WebTopBar(
          userName: userName,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(
              desktop ? 28 : 20,
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
      height: 76,
      padding: const EdgeInsets.symmetric(
        horizontal: 28,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFEEE7E2),
          ),
        ),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Lobby',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: LobbyScreen.textDark,
              ),
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.notifications_none_rounded,
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 19,
            backgroundColor: LobbyScreen.burgundy,
            child: Text(
              _initials(userName),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            userName,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: LobbyScreen.textDark,
            ),
          ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Buenas tardes, $userName',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: LobbyScreen.textDark,
          ),
        ),
        const SizedBox(height: 24),
        const _SectionTitle(
          title: 'RESUMEN DE HOY',
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 820) {
              return const Row(
                children: [
                  Expanded(
                    child: _WebSummaryCard(
                      value: 'C\$ 1,950',
                      label: 'Ingresos',
                      color: LobbyScreen.burgundy,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _WebSummaryCard(
                      value: '4',
                      label: 'Ventas',
                      color: LobbyScreen.burgundy,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _WebSummaryCard(
                      value: '2',
                      label: 'Stock bajo',
                      color: LobbyScreen.amber,
                    ),
                  ),
                ],
              );
            }

            return const Column(
              children: [
                _WebSummaryCard(
                  value: 'C\$ 1,950',
                  label: 'Ingresos',
                  color: LobbyScreen.burgundy,
                ),
                SizedBox(height: 12),
                _WebSummaryCard(
                  value: '4',
                  label: 'Ventas',
                  color: LobbyScreen.burgundy,
                ),
                SizedBox(height: 12),
                _WebSummaryCard(
                  value: '2',
                  label: 'Stock bajo',
                  color: LobbyScreen.amber,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 30),
        const _SectionTitle(
          title: 'ACCESOS RÁPIDOS',
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: desktop ? 2.8 : 2.2,
          children: const [
            _WebQuickCard(
              icon: Icons.shopping_cart_outlined,
              title: 'Nueva venta',
              subtitle: 'Registrar venta',
            ),
            _WebQuickCard(
              icon: Icons.inventory_2_outlined,
              title: 'Productos',
              subtitle: 'Catálogo y stock',
            ),
            _WebQuickCard(
              icon: Icons.warehouse_outlined,
              title: 'Inventario',
              subtitle: 'Ajustar existencias',
            ),
            _WebQuickCard(
              icon: Icons.people_outline,
              title: 'Usuarios',
              subtitle: 'Personal y roles',
            ),
            _WebQuickCard(
              icon: Icons.storefront_outlined,
              title: 'Sucursales',
              subtitle: 'Puntos de venta',
            ),
            _WebQuickCard(
              icon: Icons.bar_chart_outlined,
              title: 'Reportes',
              subtitle: 'Generar informes',
            ),
          ],
        ),
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
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 116,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFF0E9E4),
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
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
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
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFF0E9E4),
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
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Colors.black38,
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
      height: 68,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFECE5E0),
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
                  color: const Color(0xFFF5EEEE),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                  icon: const Icon(
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
            backgroundColor: Colors.white,
            child: ClipOval(
              child: Image.asset(
                'assets/images/romero.jpeg',
                width: 38,
                height: 38,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 9),
          const Expanded(
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
            ),
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: LobbyScreen.burgundy,
            child: Text(
              _initials(userName),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
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
    onSelected(index);
    Navigator.pop(context);
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
                    backgroundColor: Colors.white,
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/romero.jpeg',
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
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_outlined,
                      color: Colors.white70,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Gestión • Ventas • Inventario',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
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
                      icon: Icons.people_outline,
                      title: 'Usuarios',
                      active: selectedIndex == 4,
                      onTap: () {
                        select(context, 4);
                      },
                    ),
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
              onTap: () {},
            ),
            _DrawerItem(
              icon: Icons.logout_rounded,
              title: 'Cerrar sesión',
              active: false,
              onTap: () {},
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Buenas tardes, $userName',
          style: const TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w900,
            color: LobbyScreen.textDark,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Aquí tienes el resumen de Panadería Romero.',
          style: TextStyle(
            fontSize: 11,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 24),
        const _SectionTitle(
          title: 'RESUMEN DE HOY',
        ),
        const SizedBox(height: 12),
        const _MobileIncomeCard(),
        const SizedBox(height: 10),
        const Row(
          children: [
            Expanded(
              child: _MobileMetricCard(
                icon: Icons.receipt_long_outlined,
                value: '4',
                label: 'Ventas',
                color: LobbyScreen.burgundy,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _MobileMetricCard(
                icon: Icons.warning_amber_rounded,
                value: '2',
                label: 'Stock bajo',
                color: LobbyScreen.amber,
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        const _SectionTitle(
          title: 'ACCESOS RÁPIDOS',
        ),
        const SizedBox(height: 12),
        const _MobileQuickCard(
          icon: Icons.shopping_cart_outlined,
          title: 'Nueva venta',
          subtitle: 'Registrar una nueva venta',
        ),
        const SizedBox(height: 10),
        const _MobileQuickCard(
          icon: Icons.inventory_2_outlined,
          title: 'Productos',
          subtitle: 'Catálogo y existencias',
        ),
        const SizedBox(height: 10),
        const _MobileQuickCard(
          icon: Icons.warehouse_outlined,
          title: 'Inventario',
          subtitle: 'Controlar existencias',
        ),
        const SizedBox(height: 10),
        const _MobileQuickCard(
          icon: Icons.people_outline,
          title: 'Usuarios',
          subtitle: 'Personal y roles',
        ),
        const SizedBox(height: 10),
        const _MobileQuickCard(
          icon: Icons.storefront_outlined,
          title: 'Sucursales',
          subtitle: 'Puntos de venta',
        ),
        const SizedBox(height: 10),
        const _MobileQuickCard(
          icon: Icons.bar_chart_outlined,
          title: 'Reportes',
          subtitle: 'Consultar información',
        ),
        const SizedBox(height: 22),
        const _StockAlert(),
        const SizedBox(height: 12),
        const _RecentActivity(),
      ],
    );
  }
}

class _MobileIncomeCard extends StatelessWidget {
  const _MobileIncomeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFFF0E9E4),
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
            child: const Icon(
              Icons.payments_outlined,
              color: LobbyScreen.burgundy,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'C\$ 1,950',
                  style: TextStyle(
                    color: LobbyScreen.burgundy,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Ingresos de hoy',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
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
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 126,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF0E9E4),
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
            style: const TextStyle(
              fontSize: 10,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileQuickCard extends StatelessWidget {
  const _MobileQuickCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () {},
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(
            minHeight: 72,
          ),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: const Color(0xFFF0E9E4),
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
                      style: const TextStyle(
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
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                color: Colors.black38,
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
      style: const TextStyle(
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1D2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: LobbyScreen.amber,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inventario bajo',
                  style: TextStyle(
                    color: LobbyScreen.amber,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '2 productos necesitan reposición',
                  style: TextStyle(
                    fontSize: 10,
                    color: LobbyScreen.textDark,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: LobbyScreen.amber,
          ),
        ],
      ),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF0E9E4),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Actividad reciente',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Color(0xFFF7ECEC),
                child: Icon(
                  Icons.receipt_long_outlined,
                  color: LobbyScreen.burgundy,
                  size: 19,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Venta #V635 • C\$ 800.00\nJuan Pérez • 01:10 pm',
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.5,
                    color: LobbyScreen.textDark,
                  ),
                ),
              ),
              Text(
                'Ver →',
                style: TextStyle(
                  fontSize: 10,
                  color: LobbyScreen.burgundy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
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