all:
	./build.sh

package:
	zip -r out.zip image.img
