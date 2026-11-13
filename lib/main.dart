import 'package:flutter/material.dart';

import 'cinema_api.dart';

void main() => runApp(const Cinema());

const labels = {
  'title': 'Título',
  'year': 'Año de estreno',
  'director': 'Director',
  'genre': 'Género',
  'synopsis': 'Sinopsis',
  'image': 'URL del póster',
};

class Cinema extends StatelessWidget {
  const Cinema({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'PI. Catálogo de películas',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xffffbd73),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xff141319),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    home: const Home(),
  );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final api = CinemaApi();
  List<Movie> movies = [];
  bool administration = false;
  bool busy = false;
  String? error;

  Future<void> run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      error = e is Exception
          ? e.toString().replaceFirst('Exception: ', '')
          : 'No se pudo completar la solicitud.';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> refresh() async => movies = await api.movies();

  Future<void> authenticate(bool register) async {
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => EntryDialog(
        title: register ? 'Crear cuenta' : 'Iniciar sesión',
        fields: const {'email': 'Correo electrónico', 'password': 'Contraseña'},
      ),
    );
    if (values == null || !mounted) return;
    await run(() async {
      await api.authenticate(values['email']!, values['password']!, register);
      await refresh();
    });
  }

  Future<void> add() async {
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) =>
          const EntryDialog(title: 'Agregar película', fields: labels),
    );
    if (values == null || !mounted) return;
    await run(() async {
      await api.add(values);
      await refresh();
    });
  }

  Future<void> remove(Movie movie) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dar de baja película'),
        content: Text('¿Eliminar «${movie['title']}» del catálogo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await run(() async {
      await api.remove(movie.id);
      await refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = api.token != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('PI. Catálogo de películas'),
        actions: [
          if (signedIn)
            PopupMenuButton<String>(
              tooltip: 'Menú',
              enabled: !busy,
              onSelected: (value) {
                setState(() {
                  if (value == 'logout') {
                    api.signOut();
                    movies = [];
                    error = null;
                  }
                  administration = value == 'admin';
                });
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'catalog', child: Text('Catálogo')),
                if (api.admin)
                  const PopupMenuItem(
                    value: 'admin',
                    child: Text('Administración'),
                  ),
                const PopupMenuItem(
                  value: 'logout',
                  child: Text('Cerrar sesión'),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          if (busy) const LinearProgressIndicator(),
          if (error != null)
            MaterialBanner(
              content: Text(error!),
              actions: [
                if (signedIn)
                  TextButton(
                    onPressed: busy ? null : () => run(refresh),
                    child: const Text('Recargar'),
                  ),
                TextButton(
                  onPressed: () => setState(() => error = null),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          Expanded(child: signedIn ? catalog() : welcome()),
        ],
      ),
    );
  }

  Widget welcome() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          children: [
            Icon(
              Icons.local_movies_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              'Bienvenido a Cine Catálogo',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 16),
            const Text(
              'Explora películas y descubre sus historias, géneros y directores.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                FilledButton(
                  onPressed: busy ? null : () => authenticate(false),
                  child: const Text('Iniciar sesión'),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => authenticate(true),
                  child: const Text('Crear cuenta'),
                ),
              ],
            ),
            if (!CinemaApi.configured)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Text(
                  'Configura Firebase para habilitar el acceso.',
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Widget catalog() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1180),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 10,
              children: [
                Text(
                  administration ? 'Administración' : 'Catálogo de películas',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                if (administration)
                  FilledButton.icon(
                    onPressed: busy ? null : add,
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar película'),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: movies.isEmpty
                  ? Center(
                      child: Text(
                        busy
                            ? 'Cargando películas…'
                            : 'El catálogo está vacío.',
                      ),
                    )
                  : administration
                  ? ListView.builder(
                      itemCount: movies.length,
                      itemBuilder: (_, index) {
                        final movie = movies[index];
                        return ListTile(
                          title: Text(movie['title']),
                          subtitle: Text(movie['year']),
                          trailing: IconButton(
                            tooltip: 'Eliminar película',
                            onPressed: busy ? null : () => remove(movie),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        );
                      },
                    )
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 230,
                            mainAxisExtent: 284,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                      itemCount: movies.length,
                      itemBuilder: (_, index) {
                        final movie = movies[index];
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => Detail(movie: movie),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: Poster(movie: movie)),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(
                                    movie['title'],
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}

class Poster extends StatelessWidget {
  const Poster({super.key, required this.movie});
  final Movie movie;
  @override
  Widget build(BuildContext context) => Image.network(
    movie['image'],
    fit: BoxFit.cover,
    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
    semanticLabel: 'Póster de ${movie['title']}',
    errorBuilder: (_, _, _) => const ColoredBox(
      color: Color(0xff2c2933),
      child: Center(
        child: Icon(
          Icons.hide_image_outlined,
          size: 44,
          semanticLabel: 'Póster no disponible',
        ),
      ),
    ),
  );
}

class Detail extends StatelessWidget {
  const Detail({super.key, required this.movie});
  final Movie movie;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Detalle de película')),
    body: Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 220, height: 320, child: Poster(movie: movie)),
              const SizedBox(height: 24),
              Text(
                movie['title'],
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 16),
              for (final field in ['year', 'director', 'genre', 'synopsis'])
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        labels[field]!,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      SelectableText(movie[field]),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class EntryDialog extends StatefulWidget {
  const EntryDialog({super.key, required this.title, required this.fields});
  final String title;
  final Map<String, String> fields;
  @override
  State<EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends State<EntryDialog> {
  final form = GlobalKey<FormState>();
  late final controllers = {
    for (final field in widget.fields.keys) field: TextEditingController(),
  };

  String? validate(String field, String? input) {
    final value = input?.trim() ?? '';
    if (value.isEmpty) return 'Completa este campo.';
    if (field == 'email' && !RegExp(r'^\S+@\S+\.\S+$').hasMatch(value)) {
      return 'Ingresa un correo válido.';
    }
    if (field == 'password' && (input?.length ?? 0) < 6) {
      return 'Usa al menos 6 caracteres.';
    }
    if (field == 'year' && !RegExp(r'^\d{4}$').hasMatch(value)) {
      return 'Ingresa un año de cuatro cifras.';
    }
    if (field == 'image') {
      final uri = Uri.tryParse(value);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        return 'Ingresa una URL HTTPS válida.';
      }
    }
    return null;
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    scrollable: true,
    content: SizedBox(
      width: 460,
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final field in widget.fields.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: controllers[field.key],
                  decoration: InputDecoration(labelText: field.value),
                  obscureText: field.key == 'password',
                  maxLines: field.key == 'synopsis' ? 4 : 1,
                  keyboardType: switch (field.key) {
                    'year' => TextInputType.number,
                    'email' => TextInputType.emailAddress,
                    'image' => TextInputType.url,
                    _ => TextInputType.text,
                  },
                  validator: (value) => validate(field.key, value),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(context, {
              for (final entry in controllers.entries)
                entry.key: entry.key == 'password'
                    ? entry.value.text
                    : entry.value.text.trim(),
            });
          }
        },
        child: const Text('Continuar'),
      ),
    ],
  );
}
