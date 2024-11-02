import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

const REPO_URL = 'https://github.com/flipbook-labs/storyteller'

const config: Config = {
  title: 'Storyteller',
  tagline: 'Discovery and rendering of UI stories in Roblox',
  favicon: 'img/favicon.ico',

  url: 'https://flipbook-labs.github.io',
  baseUrl: '/storyteller/',

  organizationName: 'flipbook-labs',
  projectName: 'Storyteller',

  onBrokenLinks: 'throw',
  onBrokenMarkdownLinks: 'warn',

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

	plugins: [
		[
			"docusaurus-plugin-moonwave",
      {
        id: "moonwave",
        code: [
          "../src/",
        ],
        sourceUrl: `${REPO_URL}/blob/main`,
        projectDir: "../",
        classOrder: [
          "Storyteller",
        ],
        apiCategories: [],
      }
		]
	],

  presets: [
    [
      'classic',
      {
        docs: {
          sidebarPath: './sidebars.ts',
          editUrl: REPO_URL,
        },
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    // Replace with your project's social card
    image: 'img/docusaurus-social-card.jpg',
    navbar: {
      title: 'Storyteller',
      logo: {
        alt: 'My Site Logo',
        src: 'img/apple-touch-icon.png',
      },
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'docs',
          position: 'left',
          label: 'Docs',
        },
				{
					to: "/api/",
          label: "API",
          position: "left"
				},
				{
          type: 'docSidebar',
          sidebarId: 'specs',
          label: "Specs",
          position: "left"
				},
        {
          href: REPO_URL,
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Docs',
          items: [
            {
              label: 'Tutorial',
              to: '/docs/intro',
            },
          ],
        },
        {
          title: 'Community',
          items: [
            {
              label: 'Stack Overflow',
              href: 'https://stackoverflow.com/questions/tagged/docusaurus',
            },
            {
              label: 'Discord',
              href: 'https://discordapp.com/invite/docusaurus',
            },
            {
              label: 'Twitter',
              href: 'https://twitter.com/docusaurus',
            },
          ],
        },
        {
          title: 'More',
          items: [
            {
              label: 'Blog',
              to: '/blog',
            },
            {
              label: 'GitHub',
              href: 'https://github.com/facebook/docusaurus',
            },
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} My Project, Inc. Built with Docusaurus.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
