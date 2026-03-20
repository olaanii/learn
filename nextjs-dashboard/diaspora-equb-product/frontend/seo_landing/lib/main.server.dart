import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';

import 'app.dart';
import 'main.server.options.dart';

void main() {
  Jaspr.initializeApp(options: defaultServerOptions);

  runApp(
    Document(
      title: 'Diaspora Equb | Desktop-first Equb workspace',
      lang: 'en',
      meta: const {
        'description':
            'Diaspora Equb is a desktop-first workspace for monitoring Equb pools, reviewing contributions, and preparing payouts with clearer visibility.',
        'viewport': 'width=device-width, initial-scale=1',
      },
      head: [
        link(rel: 'preconnect', href: 'https://fonts.googleapis.com'),
        link(
          rel: 'preconnect',
          href: 'https://fonts.gstatic.com',
          attributes: const {'crossorigin': ''},
        ),
        link(
          rel: 'stylesheet',
          href:
              'https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap',
        ),
        link(rel: 'stylesheet', href: '/styles.css'),
        link(
          rel: 'preload',
          as: 'image',
          href: '/assets/landing-mobile-preview.png',
        ),
      ],
      body: const App(),
    ),
  );
}
