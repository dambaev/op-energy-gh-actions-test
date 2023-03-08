let
  # Pin nixpkgs, see pinning tutorial for more details
  nixpkgs = fetchTarball "https://github.com/NixOS/nixpkgs/archive/0f8f64b54ed07966b83db2f20c888d5e035012ef.tar.gz";
  pkgs = import nixpkgs {};

  # Single source of truth for all tests
  apiPort       = 80;

  # NixOS module shared between server and client
  sharedModule = {
    # Since it's common for CI not to have $DISPLAY available, we have to explicitly tell the tests "please don't expect any screen available"
    virtualisation.graphics = false;
  };
  op-energy-db-psk-mainnet = "91794224aff99af7f36ee0bb8f210cc99242b15803651fffe68adca52b191416";
  op-energy-db-salt-mainnet = "a9a5fc93af271ae890a28d3cf0f056c8a07e8e6d0326913909707c319fd890d4";
  bitcoind-signet-rpc-psk = "bcb61e8b0a2c6f998e9996ae1d9da4d650b44a91150d8650be6a9e5c0b67d2d4";
  bitcoind-signet-rpc-pskhmac = "6cd1a9449750a15c9f6d64b96ee089b9$9f5a5378a4ee0785fae6621c8506168af4b9e2211b2e7a1555012f5d6638744c";
  op-energy-db-psk-signet = "d1f3c429acfad94eb8e5d31546806e8590946c5f99c90c6e075ddd4d0a57c3f9";
  op-energy-db-salt-signet = "39c3a80a908523708016a2869841be3077911bc33a90882b7564d0d0eeb000db";
  op-energy-db-psk-testnet = "5b35acaa6dde71ee103fc74a3fb52e3c51091da78317dfc4fd0a212b77503f99";
  op-energy-db-salt-testnet = "2069267fa745ecd21a6963c58abf41e4d095719aaa6fff9fca6a9f68088327fb";

in pkgs.nixosTest ({
  # NixOS tests are run inside a virtual machine, and here we specify system of the machine.
  system = "x86_64-linux";

  nodes = {
    server = args@{ config, pkgs, ... }: let
      sources = pkgs.copyPathToStore ./op-energy-development;
      op-energy-host = import ./op-energy-development/host.nix {
          bitcoind-signet-rpc-pskhmac  = bitcoind-signet-rpc-pskhmac;
          bitcoind-signet-rpc-psk      = bitcoind-signet-rpc-psk;
          op-energy-db-psk-mainnet     = op-energy-db-psk-mainnet;
          op-energy-db-psk-signet      = op-energy-db-psk-signet;
          op-energy-db-salt-mainnet    = op-energy-db-salt-mainnet;
          op-energy-db-salt-signet     = op-energy-db-salt-signet;
          mainnet_node_ssh_tunnel      = false; # disable ssh_tunnel and mainnet service for github action
          OP_ENERGY_REPO_LOCATION      = ./op-energy-development/.git/modules/overlays/op-energy;
        };
    in {
      imports = [
        sharedModule
        op-energy-host
      ];
      networking.firewall.allowedTCPPorts = [ ];

      users = {
        mutableUsers = false;
        users = {
          # For ease of debugging the VM as the `root` user
          root.password = "";
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

    server.wait_for_open_port(${toString apiPort })

    expected = [
        "12345678",
    ]

    actual = json.loads(
        client.succeed(
            "${pkgs.curl}/bin/curl http://server:${toString apiPort}/api/v1/git-hash"
        )
    )

    assert expected == actual, "table query returns expected content"
  '';
})