{buildGoModule, fetchFromGitHub, acl}:
buildGoModule rec {
  pname = "oz";
  version = "0.2.6";

  src = fetchFromGitHub {
    owner = "subgraph";
    repo = "oz";
    rev = version;
    sha256 = "";
  };
  buildInputs = [acl];

  subPackages = [ "." ];

}
