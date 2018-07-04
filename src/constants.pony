primitive Constants
  fun min_idle_servers(): U32 => 4

  fun telegram_port(): String => "443"

  fun telegram_servers(): Array[(DcID, String)] val => [
    (0, "149.154.175.50")
    (1, "149.154.167.51")
    (2, "149.154.175.100")
    (3, "149.154.167.91")
    (4, "149.154.171.5")
  ]

  fun stats_interval(): U64 /* ns */ => 10_000_000_000

  fun mtp_abridged(): U32 =>     0x_ef_ef_ef_ef
  fun mtp_intermediate(): U32 => 0x_ee_ee_ee_ee
  fun mtp_secure(): U32 =>       0x_dd_dd_dd_dd
