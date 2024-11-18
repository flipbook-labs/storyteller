import { themes as prismThemes } from 'prism-react-renderer';
import type { Config } from '@docusaurus/types';
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
				alt: 'Storyteller Logo',
				src: 'img/apple-touch-icon.png',
			},
			items: [
				{
					type: 'docSidebar',
					sidebarId: 'primary',
					position: 'left',
					label: 'Home',
				},
				{
					to: "/api/",
					label: "API",
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
							label: 'Home',
							href: '/'
						},
						{
							label: 'API',
							href: '/api/Storyteller'
						},
						{
							label: 'Tech Specs',
							href: '/docs/tech-specs/intro/'
						}
					],
				},
				{
					title: 'Our work',
					items: [
						{
							label: 'Flipbook',
							href: 'https://flipbook-labs.github.io/flipbook/',
						},
						{
							label: 'ModuleLoader',
							href: 'https://flipbook-labs.github.io/module-loader/',
						},
						{
							label: 'GitHub Org',
							href: 'https://github.com/flipbook-labs',
						}
					],
				},
				{
					title: 'More',
					items: [
						{
							label: 'Discord',
							href: 'https://discord.com/channels/385151591524597761/1063913358740443336'
						},
					]
				}
			],
			copyright: `Copyright © ${new Date().getFullYear()} flipbook-labs. Built with Docusaurus.`,
		},
		prism: {
			theme: prismThemes.github,
			darkTheme: prismThemes.dracula,
			additionalLanguages: ['lua', 'bash', 'toml'],
		},
	} satisfies Preset.ThemeConfig,
};

export default config;
