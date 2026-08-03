document.querySelectorAll("[data-retrieval-check]").forEach((exercise) => {
  const input = exercise.querySelector("input");
  const checkButton = exercise.querySelector("[data-check]");
  const revealButton = exercise.querySelector("[data-reveal]");
  const feedback = exercise.querySelector(".feedback");
  const solution = exercise.querySelector(".solution");
  const acceptedAnswers = exercise.dataset.answers
    .split("|")
    .map((answer) => answer.trim().toLowerCase());

  checkButton.addEventListener("click", () => {
    const answer = input.value.trim().toLowerCase();
    const isCorrect = acceptedAnswers.includes(answer);

    feedback.textContent = isCorrect
      ? "Correct. #expect checks whether the observed behaviour matches the requirement."
      : "Not yet. Look for the Swift Testing macro that checks a Boolean expression.";
    feedback.className = `feedback ${isCorrect ? "success" : "error"}`;
  });

  revealButton.addEventListener("click", () => {
    solution.hidden = false;
  });
});
