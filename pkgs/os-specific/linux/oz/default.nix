{buildGoModule, fetchFromGitHub, acl}:
buildGoModule rec {
  pname = "oz";
  version = "0.2.6";

  src = fetchFromGitHub {
    owner = "subgraph";
    repo = "oz";
    rev = version;
    hash = "sha256-x0p376/IPGWf99p9CveJBSAaW6A62IPOKUNaSaSF66Q=";
  };
  buildInputs = [acl];

  subPackages = [ "." ];
  modSha256 = "lfZTK/ENpEHYes6sgysmdHA8Xggz5A2Q000i42FJF/o=";

}
