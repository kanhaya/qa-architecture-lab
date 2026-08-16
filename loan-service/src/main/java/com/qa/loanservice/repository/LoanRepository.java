package com.qa.loanservice.repository;

import com.qa.loanservice.model.Loan;

import java.util.List;
import java.util.Optional;

public interface LoanRepository {

    Optional<Loan> findById(Long id);

    List<Loan> findAll();

    Loan save(Loan loan);

    boolean deleteById(Long id);

    boolean existsById(Long id);
}
