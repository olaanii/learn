import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

class App extends StatelessComponent {
  const App({super.key});

  @override
  Component build(BuildContext context) {
    return main_(classes: 'landing-shell', [
      header(classes: 'landing-header', [
        a(href: '/', classes: 'brand-card', [
          img(src: '/assets/logo.png', alt: 'Diaspora Equb logo'),
        ]),
        nav(classes: 'landing-nav', [
          a(href: '#features', [.text('Features')]),
          a(href: '#insights', [.text('How It Works')]),
          a(href: '#company', [.text('Company')]),
        ]),
        div(classes: 'header-actions', [
          a(href: '/app/auth', classes: 'button button-primary', [
            .text('Open App'),
          ]),
        ]),
      ]),
      section(
        classes: 'hero-grid',
        attributes: const {'id': 'company'},
        [
          section(classes: 'panel hero-copy', [
            div(classes: 'eyebrow', [.text('Desktop-first savings workspace')]),
            h1([.text('Your Equb,'), br(), .text('Simplified.')]),
            p([
              .text(
                'Control payouts, pool activity, governance, and wallet actions from one desktop command center built around larger screens and calmer decision making.',
              ),
            ]),
            div(classes: 'hero-actions', [
              a(href: '/app/auth', classes: 'button button-primary', [
                .text('Get Started'),
              ]),
              a(href: '/app/pools', classes: 'button button-secondary', [
                .text('Explore Pools'),
              ]),
            ]),
            div(classes: 'hero-tags', [
              span([.text('Wallet-ready')]),
              span([.text('Round insights')]),
              span([.text('Payout control')]),
            ]),
          ]),
          section(classes: 'panel hero-visual', [
            div(classes: 'hero-orb hero-orb-left', const []),
            div(classes: 'hero-orb hero-orb-right', const []),
            img(
              src: '/assets/landing-mobile-preview.png',
              alt: 'Diaspora Equb mobile preview',
              classes: 'hero-image',
            ),
          ]),
        ],
      ),
      section(classes: 'content-grid', [
        section(
          classes: 'panel feature-panel',
          attributes: const {'id': 'features'},
          [
            div(classes: 'section-label', [
              .text('Security and orchestration'),
            ]),
            h2([
              .text(
                'Built for disciplined group finance, not generic wallets.',
              ),
            ]),
            p([
              .text(
                'Diaspora Equb gives members and organizers one place to review rounds, verify contribution status, track payouts, and move from discussion into action without losing context.',
              ),
            ]),
            div(classes: 'feature-list', [
              _FeatureItem(
                title: 'Contribution oversight',
                description:
                    'Review member status, missed rounds, and funding progress before the next draw opens.',
              ),
              _FeatureItem(
                title: 'Governance visibility',
                description:
                    'Keep pool rules, vote outcomes, and collateral expectations visible where decisions are actually made.',
              ),
              _FeatureItem(
                title: 'Wallet-linked execution',
                description:
                    'Move directly from insight to payout, funding, or withdrawal actions with fewer context switches.',
              ),
            ]),
          ],
        ),
        aside(
          classes: 'panel insight-panel',
          attributes: const {'id': 'insights'},
          [
            div(classes: 'section-label', [.text('How it works')]),
            h2([.text('Three calmer steps to run an Equb round.')]),
            ol(classes: 'step-list', [
              li([
                strong([.text('Set the pool.')]),
                p([
                  .text(
                    'Define contribution size, cadence, and membership terms in one shared workspace.',
                  ),
                ]),
              ]),
              li([
                strong([.text('Track every round.')]),
                p([
                  .text(
                    'Watch contribution momentum, round readiness, and payout eligibility without spreadsheet drift.',
                  ),
                ]),
              ]),
              li([
                strong([.text('Execute with confidence.')]),
                p([
                  .text(
                    'Open the app when it is time to fund wallets, verify progress, and release the next payout.',
                  ),
                ]),
              ]),
            ]),
            div(classes: 'insight-card', [
              span(classes: 'insight-metric', [.text('24/7')]),
              p([
                .text(
                  'Desktop visibility for organizers and diaspora members coordinating across time zones.',
                ),
              ]),
            ]),
          ],
        ),
      ]),
      section(classes: 'value-strip', [
        _ValueCard(
          title: 'One workspace',
          body:
              'Pool monitoring, governance review, and payout preparation stay in the same browser session.',
        ),
        _ValueCard(
          title: 'Theme-consistent experience',
          body:
              'The public landing now uses the same Ethiopian heritage palette while shipping SEO-friendly prerendered markup.',
        ),
        _ValueCard(
          title: 'App separation',
          body:
              'Marketing content stays indexable at the root while the authenticated Flutter app continues under /app.',
        ),
      ]),
    ]);
  }
}

class _FeatureItem extends StatelessComponent {
  const _FeatureItem({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Component build(BuildContext context) {
    return article(classes: 'feature-item', [
      div(classes: 'feature-dot', const []),
      div(classes: 'feature-copy', [
        h3([.text(title)]),
        p([.text(description)]),
      ]),
    ]);
  }
}

class _ValueCard extends StatelessComponent {
  const _ValueCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Component build(BuildContext context) {
    return article(classes: 'value-card', [
      h3([.text(title)]),
      p([.text(body)]),
    ]);
  }
}
