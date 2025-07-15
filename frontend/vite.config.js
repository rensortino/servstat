import vue from '@vitejs/plugin-vue';

export default {
    base: '',
    plugins: [vue()],
    css: {
        modules: {
            scopeBehaviour: 'global'
        }
    }
};