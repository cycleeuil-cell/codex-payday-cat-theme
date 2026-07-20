(() => {
  "use strict";

  const PET_ID = "payday-codex-pet";
  const SUCCESS_MS = 4800;
  const STATE_META = {
    idle: { label: "等主人提问", badge: "···", title: "月薪猫：空闲待命" },
    thinking: { label: "正在思考…", badge: "···", title: "月薪猫：正在思考" },
    working: { label: "正在工作…", badge: "</>", title: "月薪猫：正在敲代码" },
    approval: { label: "等待主人审批", badge: "!", title: "月薪猫：等待审批" },
    success: { label: "任务完成", badge: "✓", title: "月薪猫：任务完成" },
    error: { label: "任务异常", badge: "!", title: "月薪猫：任务异常" },
  };

  let pet = null;
  let labelNode = null;
  let bubbleBadgeNode = null;
  let effectNode = null;
  let currentState = "idle";
  let wasBusy = false;
  let busyStartedAt = 0;
  let successUntil = 0;
  let scheduled = 0;

  function isVisible(element) {
    if (!(element instanceof Element) || element.closest(`#${PET_ID}`)) return false;
    const style = getComputedStyle(element);
    if (style.display === "none" || style.visibility === "hidden" || style.opacity === "0") return false;
    const rect = element.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0;
  }

  function normalizedControlText(element) {
    return [
      element.getAttribute("aria-label"),
      element.getAttribute("title"),
      element.textContent,
    ]
      .filter(Boolean)
      .join(" ")
      .replace(/\s+/g, " ")
      .trim()
      .toLowerCase();
  }

  function visibleControls() {
    return Array.from(document.querySelectorAll("button, [role='button']"))
      .filter(isVisible)
      .map(normalizedControlText)
      .filter(Boolean);
  }

  function latestTurnText() {
    const turns = Array.from(document.querySelectorAll("[data-virtualized-turn-content]"))
      .filter(isVisible);
    const target = turns.at(-1) || document.querySelector("main") || document.body;
    return (target?.innerText || "").slice(-9000).toLowerCase();
  }

  function hasApprovalRequest(controls) {
    const allow = controls.some((text) =>
      /allow once|allow this conversation|always allow|approve|允许一次|允许此对话|始终允许|批准/.test(text),
    );
    const deny = controls.some((text) => /(^|\s)deny($|\s)|decline|拒绝/.test(text));
    return allow && deny;
  }

  function hasStopControl(controls) {
    return controls.some((text) =>
      /(^|\s)(stop|stop all|停止|全部停止)($|\s)/.test(text),
    );
  }

  function hasVisibleError() {
    const candidates = document.querySelectorAll(
      "[role='alert'], [data-testid*='error' i], [class*='error-foreground']",
    );
    return Array.from(candidates).some((element) => {
      if (!isVisible(element)) return false;
      const text = (element.textContent || "").replace(/\s+/g, " ").trim().toLowerCase();
      return text.length > 0 && text.length < 1200 &&
        /error|failed|couldn.t|unable|timed out|异常|错误|失败|无法|超时/.test(text);
    });
  }

  function hasActiveWork(text) {
    return /running|reading|searching|editing|creating|writing|applying|executing|calling|using tool|fetching|generating|运行中|正在运行|正在读取|正在搜索|正在编辑|正在创建|正在写入|正在调用|正在生成/.test(text);
  }

  function detectState() {
    const controls = visibleControls();
    const text = latestTurnText();
    const approval = hasApprovalRequest(controls) || /awaiting approval|等待审批|等待批准/.test(text);
    const error = hasVisibleError();
    const inProgress = hasStopControl(controls) || /(^|\s)thinking(…|\.\.\.|\s|$)|正在思考/.test(text);

    if (approval) return "approval";
    if (error && !inProgress) return "error";
    if (inProgress) {
      if (!wasBusy) busyStartedAt = Date.now();
      return hasActiveWork(text) || Date.now() - busyStartedAt > 4200 ? "working" : "thinking";
    }
    if (wasBusy) {
      successUntil = Date.now() + SUCCESS_MS;
      return "success";
    }
    if (Date.now() < successUntil) return "success";
    return "idle";
  }

  function setState(nextState) {
    if (!STATE_META[nextState]) nextState = "idle";
    const meta = STATE_META[nextState];
    if (pet) {
      pet.dataset.state = nextState;
      pet.setAttribute("aria-label", meta.title);
      pet.title = meta.title;
    }
    if (labelNode) labelNode.textContent = meta.label;
    if (bubbleBadgeNode) bubbleBadgeNode.textContent = meta.badge;
    if (effectNode) effectNode.textContent = meta.badge;
    document.documentElement.dataset.paydayPetState = nextState;
    currentState = nextState;
  }

  function evaluate() {
    scheduled = 0;
    const nextState = detectState();
    const busyNow = nextState === "thinking" || nextState === "working" || nextState === "approval";
    setState(nextState);
    wasBusy = busyNow;
  }

  function scheduleEvaluate() {
    if (scheduled) return;
    scheduled = window.setTimeout(evaluate, 180);
  }

  function mount() {
    if (!document.body || document.getElementById(PET_ID)) return;
    pet = document.createElement("aside");
    pet.id = PET_ID;
    pet.dataset.state = "idle";
    pet.setAttribute("role", "status");
    pet.setAttribute("aria-live", "polite");
    pet.innerHTML = `
      <div class="payday-pet__bubble">
        <span class="payday-pet__badge" aria-hidden="true">···</span>
        <span class="payday-pet__label">等主人提问</span>
      </div>
      <div class="payday-pet__stage" aria-hidden="true">
        <img class="payday-pet__image" src="./assets/payday-pet.png" alt="">
        <span class="payday-pet__effect">···</span>
      </div>`;
    document.body.appendChild(pet);
    labelNode = pet.querySelector(".payday-pet__label");
    bubbleBadgeNode = pet.querySelector(".payday-pet__badge");
    effectNode = pet.querySelector(".payday-pet__effect");
    setState("idle");

    const observer = new MutationObserver(scheduleEvaluate);
    observer.observe(document.body, {
      subtree: true,
      childList: true,
      characterData: true,
      attributes: true,
      attributeFilter: ["aria-label", "aria-busy", "data-state", "class", "hidden"],
    });
    window.setInterval(evaluate, 1250);
    document.addEventListener("visibilitychange", scheduleEvaluate);
    window.addEventListener("focus", scheduleEvaluate);

    window.paydayPet = Object.freeze({
      getState: () => currentState,
      detectState,
      setState,
      states: Object.keys(STATE_META),
    });
    evaluate();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", mount, { once: true });
  } else {
    mount();
  }
})();
