// Flat specificity keeps the GUI's cascade predictable (`CLAUDE.md` UI law).
export default {
  extends: ["stylelint-config-standard"],
  rules: {
    "selector-max-id": 0,
    "selector-max-specificity": "0,2,1",
  },
};
