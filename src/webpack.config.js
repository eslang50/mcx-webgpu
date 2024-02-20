module.exports = {
  mode: 'development',
  entry: './mcx.mjs',
  devServer: {
    static: './dist', 
  },
  resolve: {
    extensions: ['.js', '.mjs'], 
  },
  experiments: {
    topLevelAwait: true, 
  },
};
