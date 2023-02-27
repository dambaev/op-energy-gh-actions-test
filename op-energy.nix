let
  # Pin nixpkgs, see pinning tutorial for more details
  nixpkgs = fetchTarball "https://github.com/NixOS/nixpkgs/archive/0f8f64b54ed07966b83db2f20c888d5e035012ef.tar.gz";
  pkgs = import nixpkgs {};

  # Single source of truth for all tutorial constants
  database      = "postgres";
  schema        = "api";
  table         = "todos";
  username      = "authenticator";
  password      = "mysecretpassword";
  webRole       = "web_anon";
  postgrestPort = 3000;

  # NixOS module shared between server and client
  sharedModule = {
    # Since it's common for CI not to have $DISPLAY available, we have to explicitly tell the tests "please don't expect any screen available"
    virtualisation.graphics = false;
  };
  bitcoind-signet-rpc-psk =     builtins.readFile ( "./private/bitcoind-signet-rpc-psk.txt");
  bitcoind-signet-rpc-pskhmac = builtins.readFile ( "./private/bitcoind-signet-rpc-pskhmac.txt");
  op-energy-db-psk-signet =     builtins.readFile ( "./private/op-energy-db-psk-signet.txt");
  op-energy-db-salt-signet =    builtins.readFile ( "./private/op-energy-db-salt-signet.txt");
  bitcoind-mainnet-rpc-psk =    builtins.readFile ( "./private/bitcoind-mainnet-rpc-psk.txt");
  op-energy-db-psk-mainnet =    builtins.readFile ( "./private/op-energy-db-psk-mainnet.txt");
  op-energy-db-salt-mainnet =   builtins.readFile ( "./private/op-energy-db-salt-mainnet.txt");

in pkgs.nixosTest ({
  # NixOS tests are run inside a virtual machine, and here we specify system of the machine.
  system = "x86_64-linux";

  nodes = {
    server = { config, pkgs, ... }: {
      imports = [
        sharedModule
        ./op-energy-development/host.nix
      ];
      environment.etc = {
        "nixos/private/bitcoind-signet-rpc-psk.txt".text = bitcoind-signet-rpc-psk;
        "nixos/private/bitcoind-signet-rpc-pskhmac.txt"  = bitcoind-signet-rpc-pskhmac;
        "nixos/private/op-energy-db-psk-signet.txt"      = op-energy-db-psk-signet;
        "nixos/private/op-energy-db-salt-signet.txt"     = op-energy-db-salt-signet;
        "nixos/private/bitcoind-mainnet-rpc-psk.txt"     = bitcoind-mainnet-rpc-psk;
        "nixos/private/op-energy-db-psk-mainnet.txt"     = op-energy-db-psk-mainnet;
        "nixos/private/op-energy-db-salt-mainnet.txt"    = op-energy-db-salt-mainnet;
      };

      networking.firewall.allowedTCPPorts = [ 8999 ];

      users = {
        mutableUsers = false;
        users = {
          # For ease of debugging the VM as the `root` user
          root.password = "";

          # Create a system user that matches the database user so that we
          # can use peer authentication.  The tutorial defines a password,
          # but it's not necessary.
          "${username}".isSystemUser = true;
        };
      };

    };

    client = {
      imports = [ sharedModule ];
    };
  };

  # Disable linting for simpler debugging of the testScript
  skipLint = true;

  testScript = ''
    import json
    import sys

    start_all()

    server.wait_for_open_port(${toString postgrestPort})

    expected = [
        {"id": 1, "done": False, "task": "finish tutorial 0", "due": None},
        {"id": 2, "done": False, "task": "pat self on back", "due": None},
    ]

    actual = json.loads(
        client.succeed(
            "${pkgs.curl}/bin/curl http://server:${toString postgrestPort}/${table}"
        )
    )

    assert expected == actual, "table query returns expected content"
  '';
})