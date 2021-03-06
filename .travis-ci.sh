# Dependencies
# (Lacaml 7.2.5 or below cannot pass tests because they have a bug in the complex version of Vec.ssqr_diff)
OPAM_DEPS="ocamlfind cppo lacaml>=7.2.6 ounit"

export PREFIX="./usr"
export BINDIR="$PREFIX/bin"
export LIBDIR="$PREFIX/lib"
export PATH="$BINDIR:$PATH"

mkdir -p $PREFIX

# Download and install OPAM and OCaml
wget -q -O opam_installer.sh "https://raw.github.com/ocaml/opam/master/shell/opam_installer.sh"
if [ -n "${OPAM_VERSION:-}" ]; then
    sed -i "s/^VERSION=.*$/VERSION='$OPAM_VERSION'/" opam_installer.sh
fi
echo y | sh opam_installer.sh $BINDIR $OCAML_VERSION

# Install OCaml
export OPAMYES=1
export OPAMVERBOSE=1
opam init
eval `opam config env`

# Install OPAM packages
if [ -n "${OPAM_DEPS:-}" ]; then
    opam install $OPAM_DEPS
fi

# Test
./configure $CONFIG --enable-tests --enable-examples
make
make test

# Execute examples
for file in *.native; do
    if [ "$file" != "ppx_slap.native" ] && [ "$file" != "test.native" ] && [ "$file" != "visualization.native" ]; then
        echo "Execute ./$file";
        ./$file
    fi
done
