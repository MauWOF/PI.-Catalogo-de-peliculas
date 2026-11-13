# PI. Catálogo de películas

Aplicación desarrollada en Flutter para consultar un catálogo de películas. Permite crear una cuenta, iniciar sesión y consultar fichas con título, año de estreno, director, género, sinopsis y póster. Las cuentas administradoras pueden agregar y eliminar películas desde el menú superior.

## Cómo ejecutar la aplicación

Se requiere Flutter y Google Chrome. Abra una terminal en la carpeta del proyecto, donde se encuentra `pubspec.yaml`, y ejecute:

```powershell
flutter pub get
```

Cuando termine, ejecute este comando en una sola línea:

```powershell
flutter run -d chrome --dart-define=FIREBASE_PROJECT_ID=pi-catalogo-de-peliculas-ef0d8 --dart-define=FIREBASE_API_KEY=AIzaSyBBCuB4xHrUBXDYPo7he7X0VdcKfx99fzM
```

## Cómo probar la aplicación

1. En la pantalla de bienvenida, selecciona **Crear cuenta** o **Iniciar sesión**.
2. Abre **Catálogo** desde el menú superior y selecciona una película para ver su ficha.
3. Para probar el alta y la baja de películas, inicia sesión con la cuenta administradora de prueba proporcionada por separado y abre **Administración** en el menú superior.

La aplicación usa Firebase Authentication para gestionar las cuentas y Cloud Firestore para guardar y consultar las películas mediante solicitudes HTTPS. Al iniciar sesión, el catálogo muestra las películas guardadas en la base de datos de la entrega.