module.exports = {
  root: true,
  extends: '@react-native',
  rules: {
    'react/no-unused-prop-types': 'error',
    'react/no-unused-class-component-methods': 'error',
    '@typescript-eslint/no-unused-vars': [
      'error',
      {
        argsIgnorePattern: '^_',
        varsIgnorePattern: '^_',
        destructuredArrayIgnorePattern: '^_',
      },
    ],
  },
};
