/* protegR2 — badge buttons et dropdown panels
   Charge automatiquement via htmlDependency() */

$(function () {

  /* ── Dropdown panels ──────────────────────────────────────────────────────
     Clic sur .pr2-header-btn → ouvre le panel associe (data-panel)
     Les panels sont mutuellement exclusifs (un seul ouvert a la fois)
  -------------------------------------------------------------------------- */
  $(document).on("click", ".pr2-header-btn", function (e) {
    e.stopPropagation();
    var panelId = $(this).data("panel");
    if (!panelId) return;

    var $panel     = $("#" + panelId);
    var wasVisible = $panel.is(":visible");

    // Fermer tous les dropdowns
    $(".pr2-dropdown-panel").hide();

    // Ouvrir celui-ci s'il etait ferme
    if (!wasVisible) {
      $panel.fadeIn(150);
    }
  });

  // Fermer les dropdowns en cliquant ailleurs
  $(document).on("click", function (e) {
    if (!$(e.target).closest(".pr2-badge-wrapper, .pr2-dropdown-panel").length) {
      $(".pr2-dropdown-panel").fadeOut(100);
    }
  });

  /* ── Mise a jour du badge depuis le serveur ───────────────────────────────
     Appele via protegr2_update_badge(session, id, count)
  -------------------------------------------------------------------------- */
  Shiny.addCustomMessageHandler("pr2_update_badge", function (msg) {
    var $wrapper = $("[data-badge-id='" + msg.id + "']");
    var $badge   = $wrapper.find(".pr2-badge");

    if (msg.count && msg.count > 0) {
      if ($badge.length === 0) {
        $wrapper.append('<span class="pr2-badge">' + msg.count + "</span>");
      } else {
        $badge.text(msg.count);
      }
    } else {
      $badge.remove();
    }
  });

});
