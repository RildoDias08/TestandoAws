function build() {
	cd client
	echo "iniciando build..."
	rm -rf dist
	npm ci
	npm run build
	echo "build finalizado!"
	echo""
	cd ..
}
build

